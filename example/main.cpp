#include <fmt/core.h>

#include "versions.h"
#include "versions.hpp"


int main(int argc, char** argv)
{
    fmt::print("hello world\n");

    fmt::print("\nh\n");
    fmt::print("! '{}' '{}' '{}'\n", ProjectName, ProjectVersion, ProjectDescription);

    for(const auto& ver : ProjectDependencies)
    {
        fmt::print("* {} {}\n", ver.name, ver.version);
    }

    for(const auto& ver : TargetDependencies)
    {
        fmt::print("* {} {}\n", ver.name, ver.version);
    }

    fmt::print("\nhpp\n");

    fmt::print(
        "! '{}' '{}' '{}'\n",
        version_info::ProjectName,
        version_info::ProjectVersion,
        version_info::ProjectDescription
    );

    for(const auto& ver : version_info::ProjectDependencies)
    {
        fmt::print("* {} {}\n", ver.first, ver.second);
    }

    for(const auto& ver : version_info::TargetDependencies)
    {
        fmt::print("* {} {}\n", ver.first, ver.second);
    }
}
