cmake_minimum_required(VERSION 3.20)

#
# defaults
#

if(NOT DEFINED CMAKE_PROJECT_VAR_PREFIX)
  set(CMAKE_PROJECT_VAR_PREFIX "CM_")
endif()

if(NOT DEFINED CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD)
  set(CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD "find_package")
endif()

if(NOT DEFINED CMAKE_PROJECT_DEFAULT_GIT_BRANCH)
  set(CMAKE_PROJECT_DEFAULT_GIT_BRANCH "main")
endif()

if(NOT DEFINED CMAKE_PROJECT_EXTRA_MODULES_DIR)
  function(_cmp_set_project_extra_modules_dir)
    set(dir "${CMAKE_CURRENT_FUNCTION_LIST_DIR}")
    if(EXISTS "${dir}/cmp")
      set(dir "${dir}/cmp")
    endif()
    set(CMAKE_PROJECT_EXTRA_MODULES_DIR "${dir}" PARENT_SCOPE)
  endfunction()
  _cmp_set_project_extra_modules_dir()
  message(TRACE "CMAKE_PROJECT_EXTRA_MODULES_DIR: ${CMAKE_PROJECT_EXTRA_MODULES_DIR}")
endif()

if(NOT DEFINED CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION OR "${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}" STREQUAL "")
  set(CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION ${CMAKE_BINARY_DIR}/external)
  list(APPEND CMAKE_PREFIX_PATH ${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION})
endif()

if(NOT DEFINED CMAKE_PROJECT_AUTO_SETUP)
  set(CMAKE_PROJECT_AUTO_SETUP ON)
endif()

#
# functions
#

#
# cmp_parse_project_file(filename)
#
# Reads a cmake-project file
# This will create the following variables:
#   Format: <CMAKE_PROJECT_VAR_PREFIX><VAR_NAME>
#   VARS:
#     * PROJECT_NAME            (str)
#     * PROJECT_DESCRIPTION     (str)
#     * PROJECT_AUTHORS         (list[str])
#     * PROJECT_HOMEPAGE_URL    (str)
#     * PROJECT_REPOSITORY_URL  (str)
#     * PROJECT_README_FILE     (str)
#     * PROJECT_LICENSE_TYPE    (str)
#     * PROJECT_LICENSE_FILE    (str)
#     * PROJECT_KEYWORDS        (list[str])
#     * PROJECT_CATEGORIES      (list[str])
#     * PROJECT_LANGUAGES       (list[str])
#
#     * PROJECT_DEPENDENCIES        (json)
#     * PROJECT_DEV_DEPENDENCIES    (json)
#     * PROJECT_BUILD_DEPENDENCIES  (json)
#
# The _DEPENDENCIES variables will be further processed
# by the "cmp_find_project_dependencies" functions.
#
# @param[in] filename   Path of the cmake-projects file.
#
function(cmp_parse_project_file filename)
  message(TRACE "loading '${filename}'")
  file(READ "${filename}" filecontent)

  # project
  _CMP_READ_PROJECT_FIELD_REQ(PROJECT_NAME "${filecontent}" "name")
  _CMP_READ_PROJECT_FIELD_REQ(PROJECT_VERSION "${filecontent}" "version")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_DESCRIPTION "${filecontent}" "description" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_AUTHORS "${filecontent}" "authors" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_HOMEPAGE_URL "${filecontent}" "documentation" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_REPOSITORY_URL "${filecontent}" "repository" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_README_FILE "${filecontent}" "readme" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_LICENSE_TYPE "${filecontent}" "license" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_LICENSE_FILE "${filecontent}" "license-file" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_KEYWORDS "${filecontent}" "keywords" "")
  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_CATEGORIES "${filecontent}" "categories" "")
# FIXME
#  _READ_PROJECT_FIELD_OPT(PROJECT_LANGUAGES "${filecontent}" "languages" "C;CXX")
  set(${CMAKE_PROJECT_VAR_PREFIX}PROJECT_LANGUAGES "C;CXX" PARENT_SCOPE)

  _cmp_read_project_field(dd_data "${filecontent}" "dependency-defaults" DEFAULT "")
  _cmp_get_opt(dd_method "${dd_data}" "method" "${CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD}")
  _cmp_get_opt(dd_branch "${dd_data}" "branch" "${CMAKE_PROJECT_DEFAULT_GIT_BRANCH}")

  if(NOT "${dd_method}" STREQUAL "")
    set(CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD "${dd_method}" PARENT_SCOPE)
  endif()

  if(NOT "${dd_branch}" STREQUAL "")
    set(CMAKE_PROJECT_DEFAULT_GIT_BRANCH "${dd_branch}" PARENT_SCOPE)
  endif()

  # dependencies
  _CMP_READ_DEPENDENCIES(PROJECT_DEPENDENCIES "${filecontent}" "dependencies")
  _CMP_READ_DEPENDENCIES(PROJECT_DEV_DEPENDENCIES "${filecontent}" "dev-dependencies")
  _CMP_READ_DEPENDENCIES(PROJECT_BUILD_DEPENDENCIES "${filecontent}" "build-dependencies")

endfunction()

#
# _cmp_get_opt(result data key def)
#
# Retrieve optional entry from JSON object
#
# @param[out] result    The retreived data, or the given default value
# @param[in]  data      The input data (JSON object)
# @param[in]  key       The name of the entry to retrieve
# @param[in]  def       The default value, in case that the key is not present
#
function(_cmp_get_opt result data key def)
  string(JSON tmp ERROR_VARIABLE err GET "${data}" "${key}")
  if(NOT "${err}" STREQUAL "NOTFOUND")
    set(tmp ${def})
  endif()
  set(${result} ${tmp} PARENT_SCOPE)
endfunction()

#
# _cmp_read_project_field(result content fieldname [DEFAULT default])
#
# Reads an entry from the "project" section.
#
# @param[out] result      The value of the requested field
# @param[in]  content     The content of the project file
# @param[in]  fieldname   The name of the field to retrieve
# @param[in]  DEFAULT     Optional default value, in case that the field is not present
#
function(_cmp_read_project_field result content fieldname)
  set(oneValueArgs DEFAULT)
  cmake_parse_arguments(ARG "" "${oneValueArgs}" "" ${ARGN})

  string(JSON var ERROR_VARIABLE error GET "${content}" "project" "${fieldname}")
  if("${error}" STREQUAL "NOTFOUND")
    string(JSON var_type TYPE "${content}" "project" "${fieldname}")
    if("${var_type}" STREQUAL "STRING" OR "${var_type}" STREQUAL "NUMBER" OR "${var_type}" STREQUAL "BOOLEAN")
      set(${result} ${var} PARENT_SCOPE)
    elseif("${var_type}" STREQUAL "ARRAY")
      string(JSON arr_length LENGTH "${content}" "project" "${fieldname}")
      if(${arr_length} GREATER 0)
        math(EXPR arr_length "${arr_length}-1")
        foreach(idx RANGE ${arr_length})
          string(JSON entry GET "${var}" ${idx})
          list(APPEND lst "${entry}")
        endforeach()
      endif()
      set(${result} ${lst} PARENT_SCOPE)
    else()
      # TODO? NULL, OBJECT
      set(${result} ${var} PARENT_SCOPE)
    endif()
  elseif(DEFINED ARG_DEFAULT)
    set(${result} "${ARG_DEFAULT}" PARENT_SCOPE)
  elseif("DEFAULT" IN_LIST ARG_KEYWORDS_MISSING_VALUES)
    set(${result} "" PARENT_SCOPE)
  else()
    message(FATAL_ERROR "field 'project.${fieldname}' not found in cmake project file.")
  endif()
endfunction()

#
# _cmp_read_dependencies(result content fieldname)
#
# Reads the specified dependencies
#
# @param[out] result    The extracted dependencies (JSON format)
# @param[in]  content   The content of the project file
# @param[in]  fieldname The name of the dependency field to retrieve
#
function(_cmp_read_dependencies_fn result content fieldname)
  string(JSON var ERROR_VARIABLE error GET "${content}" "${fieldname}")
  if(NOT "${error}" STREQUAL "NOTFOUND")
    set(${result} "" PARENT_SCOPE)
    return()
  endif()
  set(${result} ${var} PARENT_SCOPE)
endfunction()

#
# cmp_find_project_dependencies([TYPE type])
#
# Find project dependencies using different methods (e.g. find_package, FetchContent, ...)
#
# @param[in] TYPE   Type of dependecies to process (prod, dev, build, all). Default: all
#
function(cmp_find_project_dependencies)
  set(oneValueArgs TYPE)
  cmake_parse_arguments(ARG "" "${oneValueArgs}" "" ${ARGN})

  set(allowed_types "prod;dev;build")

  if(NOT DEFINED ARG_TYPE)
    set(ARG_TYPE ${allowed_types})
  elseif("${ARG_TYPE}" STREQUAL "all")
    set(ARG_TYPE ${allowed_types})
  elseif(NOT "${ARG_TYPE}" IN_LIST allowed_types)
    message(FATAL_ERROR "Invalid dependency type '${ARG_TYPE}'. Possible values: prod, dev, build")
  endif()

  foreach(type IN ITEMS ${ARG_TYPE})
    _cmp_find_project_dependencies(${type})
  endforeach()
endfunction()

#
# _cmp_find_project_dependencies(type)
#
# Find project dependencies using different methods (e.g. find_package, ...)
#
# @param[in] type   Type of dependencies to process (prod, dev, build)
#
function(_cmp_find_project_dependencies type)
  if("${type}" STREQUAL "prod")
    set(deps_var PROJECT_DEPENDENCIES)
  elseif("${type}" STREQUAL "dev")
    set(deps_var PROJECT_DEV_DEPENDENCIES)
  elseif("${type}" STREQUAL "build")
    set(deps_var PROJECT_BUILD_DEPENDENCIES)
  else()
    message(FATAL_ERROR "Invalid dependency type '${type}'.\n  Possible values: prod, dev, build")
  endif()

  set(deps ${${CMAKE_PROJECT_VAR_PREFIX}${deps_var}})

  string(JSON length ERROR_VARIABLE error LENGTH "${deps}")
  if(NOT "${error}" STREQUAL "NOTFOUND")
    return()
  endif()
  if(${length} LESS_EQUAL 0)
    return()
  endif()

  message(DEBUG "[M] ${type} dependencies")

  math(EXPR length "${length}-1")
  foreach(idx RANGE ${length})
    string(JSON key MEMBER "${deps}" ${idx})
    string(JSON dep GET "${deps}" ${key})
    _cmp_find_project_dependency(${key} ${dep})
  endforeach()

endfunction()

#
# _cmp_find_project_dependency(name data)
#
# Find a single dependency using different methods (e.g. find_package, ...)
#
# @param[in]  name    Name of the dependency
# @param[in]  data    Additional dependency information (JSON formatted)
#
function(_cmp_find_project_dependency name data)
  _cmp_get_opt(method   "${data}" "method"  "")
  _cmp_get_opt(git_url  "${data}" "git"     "")

  if("${method}" STREQUAL "")
    set(method "${CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD}")
  endif()

  if(NOT COMMAND cmp_${method})
    if(EXISTS ${CMAKE_PROJECT_EXTRA_MODULES_DIR}/cmp_${method}.cmake)
      include(${CMAKE_PROJECT_EXTRA_MODULES_DIR}/cmp_${method}.cmake)
    else()
      message(DEBUG "${CMAKE_PROJECT_EXTRA_MODULES_DIR}/cmp_${method}.cmake does not exist")
    endif()
  endif()
  if(COMMAND cmp_${method})
    cmake_language(CALL cmp_${method} "${name}" "${data}")
  else()
    message(FATAL_ERROR "Unknown dependency method '${method}'.")
  endif()
endfunction()

#
# cmp_find_package(name data)
#
# Find and install dependency via find_package
#
# @param[in] name   Name of the dependency
# @param[in] data   Additional parameters
#
function(cmp_find_package name data)
  _cmp_get_opt(version        "${data}" "version"             "")
  _cmp_get_opt(quiet          "${data}" "quiet"               ON)
  _cmp_get_opt(module         "${data}" "module"              OFF)
  _cmp_get_opt(optional       "${data}" "optional"            OFF)
  _cmp_get_opt(components     "${data}" "components"          "")
  _cmp_get_opt(components_opt "${data}" "optional_components" "")
  _cmp_get_opt(global         "${data}" "global"              OFF)

  string(JSON data_type TYPE "${data}")
  if("${data_type}" STREQUAL "STRING" OR "${data_type}" STREQUAL "NUMBER")
    set(version     "${data}")
  endif()

  list(APPEND params "${name}")
  if(NOT "${version}" STREQUAL "")
    list(APPEND params "${version}")
  endif()
  if(${quiet})
    list(APPEND params QUIET)
  endif()
  if(${module})
    list(APPEND params MODULE)
  endif()
  if(NOT ${optional})
    list(APPEND params REQUIRED)
  endif()
  if(NOT "${components}" STREQUAL "")
    list(APPEND params COMPONENTS ${components})
  endif()
  if(NOT "${components_opt}" STREQUAL "")
    list(APPEND OPTIONAL_COMPONENTS ${components_opt})
  endif()
  if(${global})
    list(APPEND params GLOBAL)
  endif()
  # TODO: see full signature https://cmake.org/cmake/help/latest/command/find_package.html#id8
  find_package(${params})
endfunction()

#
# cmp_fetch_content(name data)
#
# Find and install dependency via FetchContent
#
# @param[in] name   Name of the dependency
# @param[in] data   Additional parameters
#
function(cmp_fetch_content name data)
  _cmp_parse_common_properties(params "${data}")

  include(FetchContent)
  FetchContent_Declare("${name}" ${params})
  FetchContent_MakeAvailable("${name}")
  # if(NOT ${name} IN_LIST fetch_content_libs)
  #   list(APPEND fetch_content_libs ${name})
  # endif()
endfunction()

#
# cmp_external_project(name data)
#
# Find and install dependency via ExternalProject
#
# @param[in] name   Name of the dependency
# @param[in] data   Additional parameters
#
function(cmp_external_project)
  _cmp_parse_common_properties(params "${data}")

  include(ExternalProject)
  ExternalProject_Add("${name}" ${params})
endfunction()

#
# _cmp_parse_common_properties(result data)
#
# Parses common properties for fetch_content and external_project
#
# @params[out] result   Parsed parameters
# @params[in]  data     Input data
#
function(_cmp_parse_common_properties result data)
  _cmp_get_opt(version              "${data}" "version"             "")
  _cmp_get_opt(git_repository       "${data}" "git_repository"      "")
  _cmp_get_opt(git_tag              "${data}" "git_tag"             "")
  _cmp_get_opt(git_shallow          "${data}" "git_shallow"         true)
  _cmp_get_opt(url                  "${data}" "url"                 "")
  _cmp_get_opt(url_hash             "${data}" "url_hash"            "")
  _cmp_get_opt(update_disconnected  "${data}" "update_disconnected" true)
  _cmp_get_opt(cmake_args           "${data}" "cmake_args"          "")
  _cmp_get_opt(depends              "${data}" "depends"             "")

  if(DEFINED CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION)
    list(PREPEND cmake_args "-D" "CMAKE_INSTALL_PREFIX=${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}")
  endif()

  if(DEFINED CMAKE_BUILD_TYPE)
    list(PREPEND cmake_args "-D" "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
  endif()

  list(APPEND params UPDATE_DISCONNECTED ${update_disconnected})

  if(NOT "${git_repository}" STREQUAL "")
    list(APPEND params GIT "${git_repository}")

    if(NOT "${git_tag}" STREQUAL "")
      list(APPEND params GIT_TAG "${git_tag}")
    endif()

    list(APPEND params GIT_SHALLOW ${git_shallow})
  elseif(NOT "${url}" STREQUAL "")
    string(REPLACE "{{version}}" "${version}" url "${url}")

    list(APPEND params URL "${url}")

    if(NOT "${url_hash}" STREQUAL "")
      list(APPEND params URL_HASH "${url_hash}")
    endif()

    list(APPEND params DOWNLOAD_EXTRACT_TIMESTAMP ON)
  else()
    message(FATAL_ERROR "fetch_content requires 'git' or 'url'.")
  endif()

  if(NOT "${depends}" STREQUAL "")
    list(APPEND params DEPENDS ${depends})
  endif()

  set(${result} ${params} PARENT_SCOPE)
endfunction()

#
# _CMP_READ_PROJECT_FIELD_REQ(result content fieldname)
#
# Helper macro to read required JSON property
#
# @param[out] result      Property value
# @param[in]  content     JSON input
# @param[in]  fieldname   Name of the property
#
macro(_CMP_READ_PROJECT_FIELD_REQ result content fieldname)
  _cmp_read_project_field(var "${content}" "${fieldname}")
  set(${CMAKE_PROJECT_VAR_PREFIX}${result} ${var} PARENT_SCOPE)
endmacro()

#
# _CMP_READ_PROJECT_FIELD_OPT(result content fieldname default)
#
# Helper macro to read optional JSON property
#
# @param[out] result      Property value
# @param[in]  content     JSON input
# @param[in]  fieldname   Name of the property
# @param[in]  default     Default value in case that the property is not present
#
macro(_CMP_READ_PROJECT_FIELD_OPT result content fieldname default)
  _cmp_read_project_field(var "${content}" "${fieldname}" DEFAULT "${default}")
  set(${CMAKE_PROJECT_VAR_PREFIX}${result} ${var} PARENT_SCOPE)
endmacro()

#
# _CMP_READ_DEPENDENCIES(result content fieldname)
#
# Helper macro to read dependencies
#
# @param[out] result      Dependencies (JSON formatted)
# @param[in]  content     JSON input
# @param[in]  fieldname   Name of the dependency field
#
macro(_CMP_READ_DEPENDENCIES result content fieldname)
  _cmp_read_dependencies_fn(var "${content}" "${fieldname}")
  set(${CMAKE_PROJECT_VAR_PREFIX}${result} ${var} PARENT_SCOPE)
endmacro()

#
# auto-magic
#

if(DEFINED CMAKE_PROJECT_FILE)
  cmp_parse_project_file(${CMAKE_PROJECT_FILE})
else()
  macro(_cmp_search_and_load rootdir)
    set(__candidates cmake-project.json cmake_project.json cmakeproject.json CMakeProject.json)
    foreach(file IN ITEMS ${__candidates})
      if(EXISTS ${rootdir}/${file})
        cmp_parse_project_file(${rootdir}/${file})
        set(__candidate_found 1)
        break()
      endif()
    endforeach()
    if(NOT DEFINED __candidate_found)
      message(FATAL_ERROR "no suitable cmake project file found in '${rootdir}'")
    endif()
  endmacro()
  _cmp_search_and_load(${CMAKE_SOURCE_DIR})
endif()

if(${CMAKE_PROJECT_AUTO_SETUP})
  list(APPEND CM_PROJECT_PARAMS "${CM_PROJECT_NAME}")
  if(NOT "${CM_PROJECT_VERSION}" STREQUAL "")
    list(APPEND CM_PROJECT_PARAMS VERSION "${CM_PROJECT_VERSION}")
  endif()
  if(NOT "${CM_PROJECT_DESCRIPTION}" STREQUAL "")
    list(APPEND CM_PROJECT_PARAMS DESCRIPTION "${CM_PROJECT_DESCRIPTION}")
  endif()
  if(NOT "${CM_PROJECT_HOMEPAGE_URL}" STREQUAL "")
    list(APPEND CM_PROJECT_PARAMS HOMEPAGE_URL "${CM_PROJECT_HOMEPAGE_URL}")
  endif()
  if(NOT "${CM_PROJECT_LANGUAGES}" STREQUAL "")
    list(APPEND CM_PROJECT_PARAMS LANGUAGES ${CM_PROJECT_LANGUAGES})
  endif()

  project(${CM_PROJECT_PARAMS})

  cmp_find_project_dependencies()
endif()
