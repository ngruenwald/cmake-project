import argparse
import datetime
import json
import os
import regex
import requests

from functools import cmp_to_key
from hashlib import sha256
from subprocess import Popen
from time import sleep


TOKEN: str | None = None


class Change:
    def __init__(self, package: str, old_version: str, new_version: str, recipe_file: str | None):
        self.package = package
        self.old_version = old_version
        self.new_version = new_version
        self.recipe_file = recipe_file


def set_token(token: str) -> None:
    global TOKEN
    TOKEN = token


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Force check")
    parser.add_argument("--token", default=None, help="Github access token")
    parser.add_argument("--yes", action="store_true", help="Accept all changes")
    parser.add_argument("--output", default=None, help="Output file")
    parser.add_argument("--package", default=None, help="Process only specified package")
    parser.add_argument("--add", default=None, help="Add new package")
    parser.add_argument("--delay", type=float, default=None, help="Delay in seconds between package checks")
    parser.add_argument("--commit", action="store_true", help="Create commit")
    parser.add_argument("--recipes", action="store_true", help="Update recipe files")
    args = parser.parse_args()

    if args.token is not None:
        set_token(args.token)
    else:
        set_token(os.getenv("TOKEN"))

    changes: list[Change] = []
    now = datetime.datetime.now(datetime.UTC)
    data = read_version_file("versions.json")
    data["meta"]["date"] = now.isoformat()
    if args.add:
        parts = args.add.split(":", maxsplit=1)
        package = parts[0]
        version = parts[1] if len(parts) > 1 else ""
        info = {"version": version}
        change = update_package(package, info, args.force, args.yes, args.recipes)
        if change:
            changes.append(change)
        data["versions"].update({package: info})
    else:
        for package, info in data["versions"].items():
            if args.delay:
                sleep(args.delay)
            if not args.package or args.package == package:
                change = update_package(package, info, args.force, args.yes, args.recipes)
                if change:
                    changes.append(change)
    # filename = args.output if args.output else f"versions-{now.date().isoformat()}.json"
    filename = args.output if args.output else "versions.json"
    write_version_file(filename, data)
    if changes and args.commit:
        create_commit(filename, changes)


def read_version_file(name: str) -> dict:
    with open(name, "r") as stream:
        return json.load(stream)


def write_version_file(name: str, data: dict) -> None:
    with open(name, "w") as stream:
        stream.write(json.dumps(data, indent=2, sort_keys=True))


def update_package(package: str, info: dict, force: bool, auto_accept: bool, update_recipe) -> Change | None:
    # TODO: lookup additional information from recipe file!
    # NOTE: currently we check all packages against github
    try:
        print(f"* checking {package}")

        version = info["version"]

        # branch names
        if version in ["main", "master"]:
            print("  skipping branch")
            return None

        # commits
        if version.startswith("#"):
            print("  skipping commit")
            return None

        tags = api_get_list(f"https://api.github.com/repos/{package}/tags")
        tags = filter_tags(tags, info.get("tag_filter"))
        tags = sorted(tags, key=cmp_to_key(compare_tag_versions))
        tag = tags[0]

        tag_version = trim_version_string(tag["name"])

        if force:
            needs_update = True
        else:
            needs_update = compare_versions(parse_version(version), parse_version(tag_version)) < 0
            if needs_update and not auto_accept:
                needs_update =  ask_user(f"  update {package} from {version} to {tag_version}?")

        if not needs_update:
            print("  no updates")
            return None

        commit_sha = tag["commit"]["sha"]
        commit = api_get(f"https://api.github.com/repos/{package}/git/commits/{commit_sha}").json()

        info["version"] = tag_version
        info["date"] = commit["author"]["date"]
        # info["sha256"] = get_file_hash(tag["zipball_url"])
        file_url = f"https://github.com/{package}/archive/refs/tags/{tag['name']}.zip"
        info["sha256"] = get_file_hash(file_url)

        recipe_file = None

        if update_recipe:
            recipe_file = info.get("recipe")
            if recipe_file:
                update_recipe_version(recipe_file, tag_version)

        print(f"  {version } -> {tag_version}")

        return Change(package, version, tag_version, recipe_file)

    except Exception as error:
        print(error)
        return None


def update_recipe_version(recipe: str, version: str) -> None:
    try:
        with open(recipe, "r") as stream:
            data = json.load(stream)
        if data["version"] == version:
            return
        data["version"] = version
        with open(recipe, "w") as stream:
            stream.write(json.dumps(data, indent=2))
    except Exception as err:
        print(f"  failed to update recipe: {err}")


def compare_tag_versions(a: str, b: str) -> int:
    tag_a = parse_version(a["name"])
    tag_b = parse_version(b["name"])
    return compare_versions(tag_b, tag_a)


def compare_versions(a, b) -> int:
    len_a = len(a)
    len_b = len(b)
    length = len_a if len_a < len_b else len_b
    for idx in range(0, len(a)):
        if a[idx] == b[idx]:
            continue
        return a[idx] - b[idx]
    return 0


def parse_version(s: str):
    def to_int(parts, idx) -> int:
        try:
            return int(parts[idx])
        except Exception:
            return 0

    delimiter = "."
    extra_delimiters = ["_", "-", "+"]
    s = trim_version_string(s)
    if len(s) > 0:
        for ed in extra_delimiters:
            s = s.replace(ed, delimiter)
    parts = s.split(delimiter)
    major = to_int(parts, 0)
    minor = to_int(parts, 1)
    patch = to_int(parts, 2)
    tweak = to_int(parts, 3)
    crazy = to_int(parts, 4)
    return (major, minor, patch, tweak, crazy)


def trim_version_string(s: str) -> str:
    if not s:
        return s
    for idx in range(0, len(s)):
        if s[idx].isnumeric():
            break
    return s[idx:].strip()


def get_file_hash(url: str) -> str:
    data = api_get(url).content
    return sha256(data).hexdigest()


def api_get(url: str):
    num_loops = 10
    wait_seconds = 60
    for _ in range(0, num_loops):
        headers = { "Authorization": f"Bearer {TOKEN}" } if TOKEN else None
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code == 403:
            # API rate limit?
            print("403 - waiting 60 seconds ...")
            sleep(wait_seconds)
        else:
            break
    response.raise_for_status()
    return response


def api_get_list(url: str) -> list:
    response = api_get(url)
    data = list(response.json())

    try:
        next_link = response.links["next"]["url"]
    except KeyError:
        next_link = None

    if next_link:
        sub_data = api_get_list(next_link)
        data.extend(sub_data)

    return data


def filter_tags(tags: list, tag_filter: str) -> list:
    if not tag_filter:
        return tags
    return [t for t in tags if regex.match(tag_filter, t.get("name", ""))]


def ask_user(question: str) -> bool:
    while True:
        inp = input(f"{question} [Y/n] ").lower()
        if inp == "":
            return True
        if inp == "y":
            return True
        if inp == "n":
            return False


def create_commit(filename: str, changes: list[Change]) -> bool:
    message = "maint: update versions\n"
    for change in changes:
        message += f"\n  * {change.package} {change.new_version}"
    commands = [
        ["git", "add", filename],
        ["git", "commit", "-m", message]
    ]
    for change in changes:
        if change.recipe_file:
            commands.insert(0, ["git", "add", change.recipe_file])
    for command in commands:
        proc = Popen(command)
        if proc.wait() != 0:
            return False
    return True


if __name__ == "__main__":
    main()
