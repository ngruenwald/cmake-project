# https://github.com/ngruenwald/cmake-project
# SPDX-License-Identifier: MIT

function(create_versions_h target)
  set(
    template
[=[
#ifndef __VERSIONS_H__
#define __VERSIONS_H__

struct VersionInfo
{
    const char* name;
    const char* version;
};

static const char* ProjectName = "@PROJECT_NAME@";
static const char* ProjectVersion = "@PROJECT_VERSION@";
static const char* ProjectDescription = "@PROJECT_DESCRIPTION@";

static const struct VersionInfo ProjectDependencies[]
{
@project_dependencies@
};

static const struct VersionInfo TargetDependencies[]
{
@target_dependencies@
};

#endif // __VERSIONS_H__
]=]
  )

  _create_versions_header(${target} "versions.h" ${template})
endfunction()


function(create_versions_hpp target)
  set(
    template
[=[
#pragma once

#include <array>
#include <string_view>

namespace version_info {

static constexpr std::string_view ProjectName{"@PROJECT_NAME@"};
static constexpr std::string_view ProjectVersion{"@PROJECT_VERSION@"};
static constexpr std::string_view ProjectDescription{"@PROJECT_DESCRIPTION@"};

template<std::size_t N> using VersionInfoArray =
    std::array<std::pair<std::string_view, std::string_view>, N>;

static constexpr VersionInfoArray<@project_dependencies_count@> ProjectDependencies =
{{
@project_dependencies@
}};

static constexpr VersionInfoArray<@target_dependencies_count@> TargetDependencies =
{{
@target_dependencies@
}};

} // namespace version_info
]=]
  )

  _create_versions_header(${target} "versions.hpp" "${template}")
endfunction()


function(_create_versions_header target filename template)
  if("${template}" STREQUAL "")
    set(input_filename "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/versions_info_header/${filename}.in")
    file(READ "${input_filename}" template)
  endif()

  set(output_filename "${CMAKE_CURRENT_BINARY_DIR}/${filename}")
  _get_formatted_project_dependencies(project_dependencies project_dependencies_count "${CM_PROJECT_DEPENDENCIES}")
  _get_formatted_target_dependencies(target_dependencies target_dependencies_count ${target})
  file(CONFIGURE OUTPUT "${output_filename}" CONTENT "${template}")
endfunction()


function(_get_formatted_target_dependencies result count target)
  set(tmp "")

  get_target_property(deps ${target} LINK_LIBRARIES)

  if("${deps}" STREQUAL "deps-NOTFOUND")
    message("== " "No dependencies found. Make sure to call 'create_versions_hpp' after 'target_link_libraries'.")
    set(deps)
  endif()

  list(LENGTH deps len)

  foreach(dep IN ITEMS ${deps})
    get_target_property(version ${dep} VERSION)
    if("${version}" STREQUAL "version-NOTFOUND")
      set(version "")
    endif()
    string(APPEND tmp "    { \"${dep}\", \"${version}\" },\n")
  endforeach()

  set(${result} "${tmp}" PARENT_SCOPE)
  set(${count} "${len}" PARENT_SCOPE)
endfunction()


function(_get_formatted_project_dependencies result count dependencies)
  set(tmp "")

  if("${dependencies}" STREQUAL "")
    set(dependencies ${CM_PROJECT_DEPENDENCIES})
  endif()

  string(JSON deps_length ERROR_VARIABLE error LENGTH "${dependencies}")
  if(NOT "${error}" STREQUAL "NOTFOUND")
    set(${result} "${tmp}" PARENT_SCOPE)
    return()
  endif()
  if(${deps_length} LESS_EQUAL 0)
    set(${result} "${tmp}" PARENT_SCOPE)
    return()
  endif()

  math(EXPR length "${deps_length}-1")
  foreach(idx RANGE ${length})
    string(JSON key MEMBER "${dependencies}" ${idx})
    string(JSON dep GET "${dependencies}" ${key})
    string(JSON ver ERROR_VARIABLE err GET "${dep}" "version")
    if(NOT "${err}" STREQUAL "NOTFOUND")
      set(ver "")
    endif()
    string(APPEND tmp "    { \"${key}\", \"${ver}\" },\n")
  endforeach()

  set(${result} "${tmp}" PARENT_SCOPE)
  set(${count} "${deps_length}" PARENT_SCOPE)
endfunction()
