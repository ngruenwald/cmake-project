# CMake Project

This CMake module is inspired by Rust's _cargo.toml_
and Python's _pyproject.toml_ files.

## File Format

Unfortunately there is no easy way to parse TOML files with CMake,
but CMake does have support for working with JSON data, so JSON it is.

### Minimal Example

```.json
{
    "package": {
        "name": "hello_world",
        "version": "0.1.0",
        "description": "outputs hello world"
    },
    "dependencies": {
        "fmt": "10.1.1"
    },
    "dev-dependencies": {
        "catch2": "3.4.0"
    }
}
```

The full format is defined in the [schema file][1] (wip).

### Properties

#### package

| Name                  | Type          | Description                       |
|-----                  |-----          | -----------                       |
| name                  | string        | Name of the project               |
| version               | string        | Version of the project            |
| description           | string        | Short description                 |
| authors               | list[string]  | List of author names              |
| documentation         | string        | Documentation URL                 |
| repository            | string        | Repository URL                    |
| readme                | string        | Readme file                       |
| license               | string        | License identifier                |
| license-file          | string        | License file                      |
| keywords              | list[string]  | List of keywords                  |
| categories            | list[string]  | List of categories                |
| dependency_defaults   | object        | Default settings for dependencies |

#### package.dependency_defaults

| Name    | Type    | Description                             |
|-----    |-----    |------------                             |
| method  | string  | Default method for dependency retrieval |
| branch  | string  | Default branch name for SCM operations  |

#### dependencies / dev-dependencies / build-dependencies

Dependencies can be specified as a simple string (e.g. "libfoo": "1.0.0"),
or as an object (e.g. "libfoo": { "version": "1.0.0" }).

When the simple form is used, or when the optional properties are not set,
_package.dependency_defaults_ apply.

Most properties depend on the method used (see below). But the following
properties are common to most of them.

| Name    | Type    | Description                     |
|-----    |-----    |------------                     |
| method  | string  | Retrieval/lookup method to use  |
| version | string  | Version of the dependency       |

## Builtin Methods

### find_package

This uses the [find_package][2] command.

#### find_package Properties

| Name                  | Type      | Default |
|-----                  |-----      |-------- |
| version               | string    |         |
| quiet                 | bool      | true    |
| module                | bool      | false   |
| optional              | bool      | false   |
| components            | list      |         |
| optional_components   | list      |         |
| global                | bool      | false   |

Property names match the command parameters.

### fetch_content

This uses the [FetchContent][3] module.

__NOTE:__ _FetchContent_MakeAvailable_ is currently called immediately.

#### fetch_content Properties

| Name                  | Type          | Default |
|-----                  |-----          |-------- |
| version               | string        |         |
| git_repository        | string        |         |
| git_tag               | string        |         |
| git_shallow           | bool          | true    |
| url                   | string        |         |
| url_hash              | string        |         |
| update_disconnected   | bool          | true    |
| cmake_args            | list[string]  |         |
| depends               | list[string]  |         |

### external_project

This uses the [ExternalProject][4] module.

NOT IMPLEMENTED!

#### external_project Properties

| Name                  | Type          | Default |
|-----                  |-----          |-------- |
| version               | string        |         |
| git_repository        | string        |         |
| git_tag               | string        |         |
| git_shallow           | bool          | true    |
| url                   | string        |         |
| url_hash              | string        |         |
| update_disconnected   | bool          | true    |
| cmake_args            | list[string]  |         |
| depends               | list[string]  |         |

## External Methods

Dependency handling can be extended via external methods.
To use an external method, create a file called "cmp_{method}.cmake"
which contains a function called "cmp_{{method}}".
(see [cmp_kubus.cmake][5] for an example)

<!-- References -->

[1]: schema/cmake-project.schema.json (JSON Schema)
[2]: https://cmake.org/cmake/help/latest/command/find_package.html (CMake Documentation)
[3]: https://cmake.org/cmake/help/latest/module/FetchContent.html (CMake Documentation)
[4]: https://cmake.org/cmake/help/latest/module/ExternalProject.html (CMake Documentation)
[5]: cmake/cmp_kubus.cmake (kubus_find_package)
