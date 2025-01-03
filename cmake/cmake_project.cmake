# https://github.com/ngruenwald/cmake-project
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.28)

#
# defaults
#

set(CM_EMPTY_STRING "")

if(NOT DEFINED CM_MESSAGE_PREFIX)
  set(CM_MESSAGE_PREFIX "")
endif()

if(NOT DEFINED CMAKE_PROJECT_VAR_PREFIX)
  set(CMAKE_PROJECT_VAR_PREFIX "CM_")
endif()

if(NOT DEFINED CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD)
  set(CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD "find_package")
endif()

if(NOT DEFINED CMAKE_PROJECT_DEFAULT_GIT_BRANCH)
  set(CMAKE_PROJECT_DEFAULT_GIT_BRANCH "main")
endif()

if(NOT DEFINED CMAKE_PROJECT_DEFAULT_REMOTE_RECIPE_URL)
  set(
    CMAKE_PROJECT_DEFAULT_REMOTE_RECIPE_URL
    "https://github.com/ngruenwald/cmake-project-recipes/archive/refs/heads/main.zip"
  )
endif()

if(NOT DEFINED CMAKE_PROJECT_DEFAULT_RECIPE_PATH)
  if(DEFINED CMAKE_PROJECT_EXTRA_MODULES_DIR)
    set(CMAKE_PROJECT_DEFAULT_RECIPE_PATH "${CMAKE_PROJECT_EXTRA_MODULES_DIR}/recipes")
  else()
    set(CMAKE_PROJECT_DEFAULT_RECIPE_PATH "${CMAKE_CURRENT_LIST_DIR}/recipes")
  endif()
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
  message(TRACE ${CM_MESSAGE_PREFIX} "CMAKE_PROJECT_EXTRA_MODULES_DIR: ${CMAKE_PROJECT_EXTRA_MODULES_DIR}")
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
  message(TRACE ${CM_MESSAGE_PREFIX} "loading '${filename}'")
  file(READ "${filename}" filecontent)
  string(CONFIGURE "${filecontent}" filecontent @ONLY)

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

  _cmp_read_project_field(project_languages "${filecontent}" "languages" DEFAULT "C,CXX")
  string(REPLACE "," ";" project_languages "${project_languages}")
  set(${CMAKE_PROJECT_VAR_PREFIX}PROJECT_LANGUAGES "${project_languages}" PARENT_SCOPE)

  _CMP_READ_PROJECT_FIELD_OPT(PROJECT_VARIABLES "${filecontent}" "vars" "{}")

  _cmp_read_project_field(dd_data "${filecontent}" "dependency-defaults" DEFAULT "")
  _cmp_get_opt(dd_method "${dd_data}" "method" "${CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD}")
  _cmp_get_opt(dd_branch "${dd_data}" "branch" "${CMAKE_PROJECT_DEFAULT_GIT_BRANCH}")
  _cmp_get_opt(dd_repath "${dd_data}" "recipes-path" "${CMAKE_PROJECT_DEFAULT_RECIPE_PATH}")
  _cmp_get_opt(dd_mdpath "${dd_data}" "modules-path" "${CMAKE_PROJECT_EXTRA_MODULES_DIR}")
  _cmp_get_opt(dd_remote_recipes "${dd_data}" "remote-recipes" OFF)
  _cmp_get_opt(dd_remote_recipes_url "${dd_data}" "remote-recipes-url" "${CMAKE_PROJECT_DEFAULT_REMOTE_RECIPE_URL}")

  if(NOT "${dd_method}" STREQUAL "")
    set(CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD "${dd_method}" PARENT_SCOPE)
  endif()

  if(NOT "${dd_branch}" STREQUAL "")
    set(CMAKE_PROJECT_DEFAULT_GIT_BRANCH "${dd_branch}" PARENT_SCOPE)
  endif()

  if(NOT "${dd_repath}" STREQUAL "")
    if(NOT IS_ABSOLUTE "${dd_repath}")
      get_filename_component(filepath "${filename}" DIRECTORY)
      set(dd_repath "${filepath}/${dd_repath}")
    endif()
    set(CMAKE_PROJECT_DEFAULT_RECIPE_PATH "${dd_repath}" PARENT_SCOPE)
  endif()

  if(NOT "${dd_mdpath}" STREQUAL "")
    if(NOT IS_ABSOLUTE "${dd_mdpath}")
      get_filename_component(filepath "${filename}" DIRECTORY)
      set(dd_mdpath "${filepath}/${dd_mdpath}")
    endif()
    set(CMAKE_PROJECT_EXTRA_MODULES_DIR "${dd_mdpath}" PARENT_SCOPE)
  endif()

  if(${dd_remote_recipes})
    _cmp_fetch_remote_recipes(remote_recipes_path "${dd_remote_recipes_url}")
    set(CMAKE_PROJECT_REMOTE_RECIPE_PATH "${remote_recipes_path}" PARENT_SCOPE)
  endif()

  # dependencies
  _CMP_READ_DEPENDENCIES(PROJECT_DEPENDENCIES "${filecontent}" "dependencies")
  _CMP_READ_DEPENDENCIES(PROJECT_DEV_DEPENDENCIES "${filecontent}" "dev-dependencies")
  _CMP_READ_DEPENDENCIES(PROJECT_BUILD_DEPENDENCIES "${filecontent}" "build-dependencies")

  # add to watchlist
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${filename}")
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
  string(JSON type ERROR_VARIABLE err TYPE "${data}" "${key}")

  if(NOT "${err}" STREQUAL "NOTFOUND")
    set(${result} ${def} PARENT_SCOPE)
    return()
  endif()

  if("${type}" STREQUAL "NULL")
    set(${result} "" PARENT_SCOPE)  # TODO: how to handle null?
    return()
  endif()

  string(JSON tmp GET "${data}" "${key}")

  if("${type}" STREQUAL "ARRAY")
    _cmp_convert_array(lst "${tmp}")
    set(${result} ${lst} PARENT_SCOPE)
    return()
  endif()

  #  NUMBER, STRING, BOOLEAN, or OBJECT
  set(${result} ${tmp} PARENT_SCOPE)
endfunction()

#
# _cmp_convert_array(result data [member] [empty_string])
#
# Converts a JSON array to a CMake list.
#
# @param[out] result  Output CMake list
# @param[in]  data    Input JSON data
# @param[in]  ARGV3   Optional key/index for lookup
# @param[in]  ARGV4   Optional empty string
#
function(_cmp_convert_array result data)
  if(DEFINED ${ARGV3})
    set(member "${ARGV3}")
  else()
    set(member "")
  endif()
  if(DEFINED ${ARGV4})
    set(empty_string "${ARGV4}")
  else()
    set(empty_string "${CM_EMPTY_STRING}")
  endif()

  string(JSON length ERROR_VARIABLE error LENGTH "${data}" ${member})
  if(NOT "${error}" STREQUAL "NOTFOUND")
    set(${result} "" PARENT_SCOPE)
    return()
  endif()

  if(${length} LESS_EQUAL 0)
    set(${result} "" PARENT_SCOPE)
    return()
  endif()

  math(EXPR length "${length}-1")
  foreach(idx RANGE ${length})
    string(JSON entry GET "${data}" ${member} ${idx})
    if("${entry}" STREQUAL "")
      set(entry ${empty_string})
    endif()
    list(APPEND lst "${entry}")
  endforeach()

  set(${result} ${lst} PARENT_SCOPE)
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
    set(${result} ${ARG_DEFAULT} PARENT_SCOPE)
  elseif("DEFAULT" IN_LIST ARG_KEYWORDS_MISSING_VALUES)
    set(${result} "" PARENT_SCOPE)
  else()
    message(FATAL_ERROR ${CM_MESSAGE_PREFIX} "field 'project.${fieldname}' not found in cmake project file.")
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

  set(allowed_types "dev;build;prod")

  if(NOT DEFINED ARG_TYPE)
    set(ARG_TYPE ${allowed_types})
  elseif("${ARG_TYPE}" STREQUAL "all")
    set(ARG_TYPE ${allowed_types})
  elseif(NOT "${ARG_TYPE}" IN_LIST allowed_types)
    message(FATAL_ERROR ${CM_MESSAGE_PREFIX} "invalid dependency type '${ARG_TYPE}'. Possible values: prod, dev, build")
  endif()

  # clear global properties
  set_property(GLOBAL PROPERTY __cmp_propagate_variables)
  set_property(GLOBAL PROPERTY __cmp_propagate_triggers)

  foreach(type IN ITEMS ${ARG_TYPE})
    _cmp_find_project_dependencies(${type})
  endforeach()

  # set variables (local and parent scope)
  _M_CMP_SET_VARS()
  _M_CMP_SET_VARS(PARENT_SCOPE)

  # execute trigger functions
  _M_CMP_RUN_TRIGGERS(__cmp_propagate_triggers)

  # clear global properties
  set_property(GLOBAL PROPERTY __cmp_propagate_variables)
  set_property(GLOBAL PROPERTY __cmp_propagate_triggers)
endfunction()

#
# _cmp_propagate_list_var(varname)
#
# Stores the variable content in a global property.
#
# @param[in]  varname  Name of the variable to store
#
# global properties:
#   * __cmp_propagate_variables             ... list of variables
#   * __cmp_propagate_variables_${varname}  ... variable data
#
function(_cmp_propagate_list_var varname)
  get_property(variables GLOBAL PROPERTY __cmp_propagate_variables)
  list(APPEND variables "${varname}")
  list(REMOVE_DUPLICATES variables)
  set_property(GLOBAL PROPERTY __cmp_propagate_variables "${variables}")

  if(NOT "${${varname}}" STREQUAL "")
    get_property(content GLOBAL PROPERTY __cmp_propagate_variables_${varname})
    list(APPEND content ${${varname}})
    set_property(GLOBAL PROPERTY __cmp_propagate_variables_${varname} "${content}")
  endif()
endfunction()

#
# _cmp_propagate_trigger(funcname)
#
# Stores the trigger function name in a global property.
#
# @param[in]  funcname  Name of the trigger function
#
# global properties:
#   * __cmp_propagate_triggers ... list of functions
#
function(_cmp_propagate_trigger funcname)
  get_property(triggers GLOBAL PROPERTY __cmp_propagate_triggers)
  list(APPEND triggers "${funcname}")
  set_property(GLOBAL PROPERTY __cmp_propagate_triggers "${triggers}")
endfunction()

#
# Sets the "variables" stored in the global property
#
macro(_M_CMP_SET_VARS)
  get_property(variables GLOBAL PROPERTY __cmp_propagate_variables)
  foreach(item IN ITEMS ${variables})
    get_property(content GLOBAL PROPERTY __cmp_propagate_variables_${item})
    set(${item} "${content}" ${ARGN})
  endforeach()
endmacro()

#
# Executes the "trigger" functions stored in the global property
#
macro(_M_CMP_RUN_TRIGGERS varname)
  get_property(triggers GLOBAL PROPERTY ${varname})
  list(REMOVE_DUPLICATES triggers)
  foreach(trigger IN ITEMS ${triggers})
    if(COMMAND ${trigger})
      cmake_language(CALL ${trigger})
    else()
      message(WARNING ${CM_MESSAGE_PREFIX} "unknown trigger method '${trigger}'.")
    endif()
  endforeach()
endmacro()

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
    message(FATAL_ERROR ${CM_MESSAGE_PREFIX} "invalid dependency type '${type}'.\n  Possible values: prod, dev, build")
  endif()

  set(deps ${${CMAKE_PROJECT_VAR_PREFIX}${deps_var}})

  string(JSON length ERROR_VARIABLE error LENGTH "${deps}")
  if(NOT "${error}" STREQUAL "NOTFOUND")
    return()
  endif()
  if(${length} LESS_EQUAL 0)
    return()
  endif()

  message(DEBUG ${CM_MESSAGE_PREFIX} "${type} dependencies")

  math(EXPR length "${length}-1")
  foreach(idx RANGE ${length})
    string(JSON key MEMBER "${deps}" ${idx})
    string(JSON typ TYPE   "${deps}" ${key})
    string(JSON val GET    "${deps}" ${key})

    if("${typ}" STREQUAL "OBJECT")
      set(dep ${val})
    elseif("${typ}" STREQUAL "NUMBER" OR "${typ}" STREQUAL "STRING")
      set(dep "{\"version\": \"${val}\"}")
    else()
      message(FATAL_ERROR "'${key}' has invalid type '${typ}'")
    endif()

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
  _cmp_get_opt(skip "${data}" "skip" OFF)

  if(${skip})
    message(DEBUG "ignoring \"${name}\" (skip)")
    return()
  endif()

  _cmp_get_opt(when "${data}" "when" "")

  if(NOT "${when}" STREQUAL "")
    separate_arguments(when UNIX_COMMAND ${when})

    set(condition)
    set(pattern "\\$<([^\\$<>]+)>")
    foreach(wpart IN ITEMS ${when})
      string(REGEX MATCHALL ${pattern} wmatch ${wpart})
      list(LENGTH wmatch wlength)
      if(${wlength} GREATER 0)
        foreach(wm IN ITEMS ${wmatch})
          string(REGEX REPLACE "^\\$<(.*)>$" "\\1" wtmp ${wm})
          list(APPEND condition ${${wtmp}})
        endforeach()
      else()
        list(APPEND condition ${wpart})
      endif()
    endforeach()

    message(TRACE "${name} | condition: ${condition}")

    if(${condition})
      message(DEBUG "processing \"${name}\" (when)")
    else()
      message(DEBUG "ignoring \"${name}\" (when)")
      return()
    endif()
  endif()

  # get version and hash before merging with the recipe
  _cmp_get_opt(cver "${data}" "version" "")
  _cmp_get_opt(chash "${data}" "url_hash" "")

  _cmp_get_opt(recipe "${data}" "recipe"  "")
  _cmp_load_recipe_data(data "${name}" "${data}" "${recipe}")

  # replace/clear hash if version was set in project config
  if(NOT "${cver}" STREQUAL "")
    message(DEBUG ">> ${name}: changing url_hash to '${chash}'")
    string(JSON data SET "${data}" "url_hash" "\"${chash}\"")
  endif()

  _cmp_get_opt(method "${data}" "method"  "")

  if("${method}" STREQUAL "")
    set(method "${CMAKE_PROJECT_DEFAULT_DEPENDENCY_METHOD}")
  endif()

  if(NOT COMMAND cmp_${method})
    if(EXISTS ${CMAKE_PROJECT_EXTRA_MODULES_DIR}/cmp_${method}.cmake)
      include(${CMAKE_PROJECT_EXTRA_MODULES_DIR}/cmp_${method}.cmake)
    else()
      message(DEBUG ${CM_MESSAGE_PREFIX} "${CMAKE_PROJECT_EXTRA_MODULES_DIR}/cmp_${method}.cmake does not exist")
    endif()
  endif()
  if(COMMAND cmp_${method})
    cmake_language(CALL cmp_${method} "${name}" "${data}")
  else()
    message(FATAL_ERROR ${CM_MESSAGE_PREFIX} "unknown dependency method '${method}'.")
  endif()
endfunction()


function(cmp_pkg_config name data)
  _cmp_get_opt(target "${data}" "target" "")

  find_package(PkgConfig QUIET REQUIRED)
  pkg_check_modules("${name}" REQUIRED QUIET IMPORTED_TARGET GLOBAL "${target}")

  if(${name}_FOUND)
    string(TOUPPER "${name}" uname)
    if(DEFINED ${name}_VERSION)
      set(fversion ${${name}_VERSION})
    elseif(DEFINED ${name}_VERSION_STRING)
      set(fversion ${${name}_VERSION_STRING})
    elseif(DEFINED ${uname}_VERSION)
      set(fversion ${${uname}_VERSION})
    elseif(DEFINED ${uname}_VERSION_STRING)
      set(fversion ${${uname}_VERSION_STRING})
    else()
      set(fversion ${version})
    endif()
  endif()

  message(STATUS ${CM_MESSAGE_PREFIX} "using ${name} ${fversion} (package)")
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
  _cmp_get_opt(package_name   "${data}" "name"                "")
  _cmp_get_opt(version        "${data}" "version"             "")

  _cmp_get_opt(quiet          "${data}" "quiet"               ON)
  _cmp_get_opt(module         "${data}" "module"              OFF)
  _cmp_get_opt(optional       "${data}" "optional"            OFF)
  _cmp_get_opt(components     "${data}" "components"          "NOTFOUND")
  _cmp_get_opt(components_opt "${data}" "optional_components" "NOTFOUND")
  _cmp_get_opt(global         "${data}" "global"              OFF)
  _cmp_get_opt(options        "${data}" "options"             "")

  string(JSON data_type TYPE "${data}")
  if("${data_type}" STREQUAL "STRING" OR "${data_type}" STREQUAL "NUMBER")
    set(version "${data}")
  endif()

  if("${package_name}" STREQUAL "")
    set(package_name "${name}")
  endif()

  list(APPEND params "${package_name}")
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
  if(NOT "${components}" STREQUAL "NOTFOUND")
    list(APPEND params COMPONENTS ${components})
  endif()
  if(NOT "${components_opt}" STREQUAL "NOTFOUND")
    list(APPEND OPTIONAL_COMPONENTS ${components_opt})
  endif()
  if(${global})
    list(APPEND params GLOBAL)
  endif()

  if(NOT "${options}" STREQUAL "")
    string(JSON options_count LENGTH "${options}")
    math(EXPR options_count "${options_count}-1")
    foreach(idx RANGE ${options_count})
      string(JSON key MEMBER "${options}" ${idx})
      string(JSON val GET    "${options}" ${key})
      set(${key} ${val} CACHE STRING "${name} - option - ${key}" FORCE)
    endforeach()
  endif()

  # TODO: see full signature https://cmake.org/cmake/help/latest/command/find_package.html#id8
  find_package(${params})

  if(${package_name}_FOUND)
    string(TOUPPER "${package_name}" uname)
    if(DEFINED ${package_name}_VERSION)
      set(fversion ${${package_name}_VERSION})
    elseif(DEFINED ${package_name}_VERSION_STRING)
      set(fversion ${${package_name}_VERSION_STRING})
    elseif(DEFINED ${uname}_VERSION)
      set(fversion ${${uname}_VERSION})
    elseif(DEFINED ${uname}_VERSION_STRING)
      set(fversion ${${uname}_VERSION_STRING})
    else()
      set(fversion ${version})
    endif()
  endif()

  message(STATUS ${CM_MESSAGE_PREFIX} "using ${name} ${fversion} (package)")
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

  _cmp_get_opt(exclude_from_all "${data}" "exclude_from_all"  ON)
  _cmp_get_opt(system           "${data}" "system"            ON)
  _cmp_get_opt(install_source   "${data}" "install_source"    OFF)

  if(${exclude_from_all})
    list(APPEND params EXCLUDE_FROM_ALL)
  endif()

  if(${system} AND "${CMAKE_VERSION}" VERSION_GREATER_EQUAL "3.25.0")
    list(APPEND params SYSTEM)
  endif()

  _cmp_get_opt(options "${data}" "options" "")
  if(NOT "${options}" STREQUAL "")
    string(JSON options_count LENGTH "${options}")
    math(EXPR options_count "${options_count}-1")
    foreach(idx RANGE ${options_count})
      string(JSON key ERROR_VARIABLE keyerr MEMBER "${options}" ${idx})
      if(NOT "${keyerr}" STREQUAL "NOTFOUND")
        continue()
      endif()
      string(JSON val GET    "${options}" ${key})
      set(${key} ${val} CACHE STRING "${name} - option - ${key}" FORCE)
    endforeach()
  endif()

  message(TRACE ${CM_MESSAGE_PREFIX} "fetch_content(name: ${name}, params: ${params})")

  include(FetchContent)
  FetchContent_Declare("${name}" ${params})
  FetchContent_MakeAvailable("${name}")
  # if(NOT ${name} IN_LIST fetch_content_libs)
  #   list(APPEND fetch_content_libs ${name})
  # endif()

  _cmp_get_opt(cmake_script "${data}" "cmake_script" "")
  if(NOT "${cmake_script}" STREQUAL "")
    set(cmake_script_name "${CMAKE_CURRENT_BINARY_DIR}/__todo_some_random_file_name.cmake")
    list(LENGTH cmake_script cslen)
    math(EXPR cslen "${cslen}-1")
    file(WRITE "${cmake_script_name}" "")
    foreach(idx RANGE ${cslen})
      list(GET cmake_script ${idx} csline)
      file(APPEND "${cmake_script_name}" "${csline}\n")
    endforeach()
    # file(WRITE "${cmake_script_name}" "${cmake_script}")
    include("${cmake_script_name}")
  endif()

  if(${install_source} AND NOT "${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}" STREQUAL "")
    execute_process(
      COMMAND
        "${CMAKE_COMMAND}" -E copy_directory
          "${CMAKE_BINARY_DIR}/_deps/${name}-src"
          "${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}"
    )
  endif()

  _cmp_ext_version(fversion ${data})
  _cmp_get_opt(targets "${data}" "targets" "")
  if(NOT "${targets}" STREQUAL "")
    _cmp_get_base_dirs(binary_dir include_dir)
    _cmp_create_targets("${targets}" "${fversion}" "${binary_dir}" "${include_dir}" "${name}" TRUE)
  endif()

  if(TARGET ${name})
    get_target_property(tversion ${name} VERSION)
    if("${tversion}" STREQUAL "tversion-NOTFOUND")
      set_target_properties(${name} PROPERTIES VERSION "${fversion}")
    endif()
  endif()
  
  message(STATUS ${CM_MESSAGE_PREFIX} "using ${name} ${fversion} (fetch)")
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

  _cmp_get_opt(cmake_args       "${data}" "cmake_args"      "")
  _cmp_get_opt(options_as_args  "${data}" "options_as_args" ON)

  if(${options_as_args})
    _cmp_get_opt(options "${data}" "options" "")
    if(NOT "${options}" STREQUAL "")
      string(JSON options_count LENGTH "${options}")
      math(EXPR options_count "${options_count}-1")
      foreach(idx RANGE ${options_count})
        string(JSON key MEMBER "${options}" ${idx})
        string(JSON val GET    "${options}" ${key})
        list(APPEND cmake_args "-D" "${key}=${val}")
      endforeach()
    endif()
  endif()

  if(NOT "${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}" STREQUAL "")
    list(PREPEND cmake_args "-D" "CMAKE_INSTALL_PREFIX=${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}")
  endif()

  if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "")
    list(PREPEND cmake_args "-D" "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
  endif()

  if(NOT "${cmake_args}" STREQUAL "")
    list(APPEND params CMAKE_ARGS ${cmake_args})
  endif()

  message(TRACE ${CM_MESSAGE_PREFIX} "external_project(name: ${name}, params: ${params})")

  include(ExternalProject)
  ExternalProject_Add("${name}" ${params})

  _cmp_ext_version(fversion ${data})
  _cmp_get_opt(targets "${data}" "targets" "")
  if(NOT "${targets}" STREQUAL "")
    _cmp_get_base_dirs(binary_dir include_dir)
    _cmp_create_targets("${targets}" "${fversion}" "${binary_dir}" "${include_dir}" "${name}" TRUE)
  endif()

  if(TARGET ${name})
    get_target_property(tversion ${name} VERSION)
    if("${tversion}" STREQUAL "tversion-NOTFOUND")
      set_target_properties(${name} PROPERTIES VERSION "${fversion}")
    endif()
  endif()
  
  message(STATUS ${CM_MESSAGE_PREFIX} "using ${name} ${fversion} (external)")
endfunction()

#
# _cmp_get_base_dirs
#
# @param[out] bin_dir     Binary directory (string)
# @param[out] inc_dir     Include directory (string)
function(_cmp_get_base_dirs bin_dir inc_dir)
  set(include_dir ${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}/include)
  if(${CMAKE_SIZEOF_VOID_P} EQUAL 8)
    set(libsuffix 64)
  else()
    set(libsuffix "")
  endif()
  set(binary_dir ${CMAKE_PROJECT_EXTERNAL_INSTALL_LOCATION}/lib${libsuffix})

  # if(create_dir)
  #   # We cannot use find_library because ExternalProject_Add() is performed at build time.
  #   # And to please the property INTERFACE_INCLUDE_DIRECTORIES,
  #   # we make the include directory in advance.
  #   file(MAKE_DIRECTORY ${include_dir})
  # endif()

  set(${bin_dir} ${binary_dir} PARENT_SCOPE)
  set(${inc_dir} ${include_dir} PARENT_SCOPE)
endfunction()

#
# _cmp_create_targets
#
# Create CMake targets
#
# @param[in] targets            List of targets (json array of objects)
# @param[in] version            Target version (string)
# @param[in] base_binary_dir    Base directory for binary files (string)
# @param[in] base_include_dir   Base directory for include files (string)
# @param[in] dependency         Name of a target dependency (string)
# @param[in] create_inc_dir     Create include directories (bool)
function(_cmp_create_targets targets version base_binary_dir base_include_dir dependency create_inc_dir)
  foreach(target IN ITEMS ${targets})
    _cmp_get_opt(target_name    "${target}" "target"      "")
    _cmp_get_opt(target_binary  "${target}" "binary"      "")
    _cmp_get_opt(target_include "${target}" "include-dir" "")

    if("${target_name}" STREQUAL "")
      continue()
    endif()

    if("${target_binary}" STREQUAL "")
      add_library(${target_name} INTERFACE IMPORTED GLOBAL)
    else()
      get_filename_component(binary_ext "${target_binary}" EXT)

      if("${binary_ext}" STREQUAL "")
        if(WIN32)
          set(suffix ".lib")
        else()
          set(suffix ".a")
        endif()
      endif()

      add_library(${target_name} STATIC IMPORTED GLOBAL)

      file(REAL_PATH "${base_binary_dir}/${target_binary}${suffix}" binary_path)
      set_target_properties(${target_name} PROPERTIES IMPORTED_LOCATION ${binary_path})
    endif()

    if("${target_include}" STREQUAL "")
      set(include_dir "${base_include_dir}")
    elseif(IS_ABSOLUTE "${target_include}")
      set(include_dir "${target_include}")
      set(create_inc_dir FALSE)  # TBD
    else()
      set(include_dir "${base_include_dir}/${target_include}")
    endif()

    if(${create_inc_dir})
      if(NOT "${include_dir}" STREQUAL "")
        file(MAKE_DIRECTORY ${include_dir})
      endif()
    endif()

    set_target_properties(${target_name} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${include_dir})
    set_target_properties(${target_name} PROPERTIES VERSION "${version}")

    if(NOT "${dependency}" STREQUAL "")
      add_dependencies(${target_name} ${dependency})
    endif()
  endforeach()
endfunction()

#
# _cmp_set_project_vars
#
# Set project variables in parent scope.
#
function(_cmp_set_project_vars)
  set(project_vars ${CM_PROJECT_VARIABLES})
  string(JSON length ERROR_VARIABLE error LENGTH "${project_vars}")
  if(NOT "${error}" STREQUAL "NOTFOUND")
    # do nothing
  elseif(${length} LESS_EQUAL 0)
    # do nothing
  else()
    math(EXPR length "${length}-1")
    foreach(idx RANGE ${length})
      string(JSON key MEMBER "${project_vars}" ${idx})
      string(JSON val GET    "${project_vars}" ${key})
      message(DEBUG "set ${key}=${val}")
      set(${key} ${val} PARENT_SCOPE)
    endforeach()
  endif()
endfunction()

#
# _cmp_load_recipe_data
#
# Tries to load the recipe data from the given recipe filepath.
# If no file given, a default filename based on the recipe name is used.
#
# @param[out] output  The loaded recipe data
# @param[in]  name    Dependency name
# @param[in]  data    Input data
# @param[in]  recipe  Recipe filename or path
#
function(_cmp_load_recipe_data output name data recipe)
  if("${recipe}" STREQUAL "")
    set(recipe "${name}.json")
    set(recipe_fail_no_file FALSE)
  else()
    set(recipe_fail_no_file TRUE)
  endif()

  if(NOT "${recipe}" STREQUAL "")
    # prefer local recipes
    set(recipe_path "${recipe}")
    if(NOT IS_ABSOLUTE "${recipe_path}")
      set(recipe_path "${CMAKE_PROJECT_DEFAULT_RECIPE_PATH}/${recipe_path}")
      cmake_path(NORMAL_PATH recipe_path)
    endif()
    if(NOT EXISTS "${recipe_path}" AND NOT "${CMAKE_PROJECT_REMOTE_RECIPE_PATH}" STREQUAL "")
      set(recipe_path "${recipe}")
      if(NOT IS_ABSOLUTE "${recipe_path}")
        set(recipe_path "${CMAKE_PROJECT_REMOTE_RECIPE_PATH}/${recipe_path}")
        cmake_path(NORMAL_PATH recipe_path)
      endif()
    endif()
    if(EXISTS "${recipe_path}")
      message(DEBUG ${CM_MESSAGE_PREFIX} "loading recipe '${recipe_path}'")
      file(READ "${recipe_path}" recipe_data)
      string(CONFIGURE "${recipe_data}" recipe_data @ONLY)
      _cmp_merge_json_data(data "${recipe_data}" "${data}")
      set(${output} ${data} PARENT_SCOPE)
      # add recipe to watchlist ... TODO: remove from watchlist if not required anymore
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${recipe_path}")
    else()
      if(${recipe_fail_no_file})
        message(WARNING "specified recipe configuration '${recipe}' does not exist")
      endif()
    endif()
  endif()
endfunction()

#
# _cmp_fetch_remote_recipes(url)
#
# @param[out] path  The local recipes path
# @param[in]  url   The url from where to fetch the recipes
#
function(_cmp_fetch_remote_recipes path url)
  set(data "{}")
  string(JSON data SET "${data}" "url" "\"${url}\"")
  cmp_fetch_content("cmake-project-recipes" ${data})
  get_target_property(cmp_recipes_dir cmake_project_recipes RECIPES_PATH)
  set(${path} ${cmp_recipes_dir} PARENT_SCOPE)
endfunction()

#
# _cmp_ext_version(result data)
#
# Tries to extract a version from the given data.
# Returns the configured version, or the configured git tag.
#
# @param[out] result  The extracted version
# @param[in]  data    JSON data
#
function(_cmp_ext_version result data)
  _cmp_get_opt(version  "${data}" "version" "")
  _cmp_get_opt(git_tag  "${data}" "git_tag" "")

  if(NOT "${version}" STREQUAL "")
    set(${result} ${version} PARENT_SCOPE)
  elseif(NOT "${git_tag}" STREQUAL "")
    set(${result} ${git_tag} PARENT_SCOPE)
  else()
    set(${result} "" PARENT_SCOPE)
  endif()

endfunction()

#
# _cmp_merge_json_data(result base additional)
#
# Merges the entries from "additional" to "base".
# Existing keys are overwritten.
#
# @param[out] result      The merged data
# @param[in]  base        The initial data
# @param[in]  additional  The data to add
#
function(_cmp_merge_json_data result base additional)
  # add/update entries from additional to base

  set(tgt ${base})

  string(JSON length LENGTH "${additional}")

  if(${length} GREATER 0)
    math(EXPR length "${length}-1")
    foreach(idx RANGE ${length})
      string(JSON key MEMBER "${additional}" ${idx})
      string(JSON val GET    "${additional}" ${key})
      string(JSON typ TYPE   "${additional}" ${key})
      if("${typ}" STREQUAL "STRING")
        string(JSON tgt SET "${tgt}" "${key}" "\"${val}\"")
      elseif("${typ}" STREQUAL "BOOLEAN")
        if(${val})
          string(JSON tgt SET "${tgt}" "${key}" true)
        else()
          string(JSON tgt SET "${tgt}" "${key}" false)
        endif()
      # elseif("${typ}" STREQUAL "ARRAY")
      # elseif("${typ}" STREQUAL "OBJECT")
      else()
        string(JSON tgt ERROR_VARIABLE err SET "${tgt}" "${key}" "${val}")
      endif()
    endforeach()
  endif()

  set(${result} ${tgt} PARENT_SCOPE)
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
  _cmp_get_opt(git_shallow          "${data}" "git_shallow"         ON)
  _cmp_get_opt(url                  "${data}" "url"                 "")
  _cmp_get_opt(url_hash             "${data}" "url_hash"            "")
  _cmp_get_opt(update_disconnected  "${data}" "update_disconnected" ON)
  _cmp_get_opt(depends              "${data}" "depends"             "NOTFOUND")
  _cmp_get_opt(build_in_source      "${data}" "build_in_source"     OFF)

  _cmp_get_opt(update_command       "${data}" "update_command"      "NOTFOUND")
  _cmp_get_opt(configure_command    "${data}" "configure_command"   "NOTFOUND")
  _cmp_get_opt(build_command        "${data}" "build_command"       "NOTFOUND")
  _cmp_get_opt(install_command      "${data}" "install_command"     "NOTFOUND")
  _cmp_get_opt(test_command         "${data}" "test_command"        "NOTFOUND")
  _cmp_get_opt(patch_command        "${data}" "patch_command"       "NOTFOUND")
  _cmp_get_opt(binary_dir           "${data}" "binary_dir"          "NOTFOUND")

  #
  # Directory Options
  #

  if(NOT "${binary_dir}" STREQUAL "NOTFOUND")
    list(APPEND params BINARY_DIR "${binary_dir}")
  endif()

  #
  # Download Step Options - URL
  #

  if(NOT "${url}" STREQUAL "")
    if("${version}" MATCHES "^#.*$")
      string(REPEAT "[0-9A-Fa-f]" 7 pattern)
      set(pattern "^#${pattern}+$")
      if("${version}" MATCHES "${pattern}")
        string(REGEX REPLACE "^#" "" version "${version}")
      endif()
    endif()

    string(REPLACE "{{version}}" "${version}" url "${url}")

    list(APPEND params URL "${url}")

    if(NOT "${url_hash}" STREQUAL "")
      list(APPEND params URL_HASH "${url_hash}")
    endif()

    list(APPEND params DOWNLOAD_EXTRACT_TIMESTAMP ON)
  endif()

  #
  # Download Step Options - Git
  #

  if(NOT "${git_repository}" STREQUAL "")
    list(APPEND params GIT_REPOSITORY "${git_repository}")

    if(NOT "${git_tag}" STREQUAL "")
      string(REPLACE "{{version}}" "${version}" git_tag "${git_tag}")
      list(APPEND params GIT_TAG "${git_tag}")
    endif()

    list(APPEND params GIT_SHALLOW ${git_shallow})
  endif()

  #
  # Update Step Options
  #

  if(NOT "${update_command}" STREQUAL "NOTFOUND")
    list(APPEND params UPDATE_COMMAND "${update_command}")
  endif()

  list(APPEND params UPDATE_DISCONNECTED ${update_disconnected})

  #
  # Patch Step Options
  #

  if(NOT "${patch_command}" STREQUAL "NOTFOUND")
    list(APPEND params PATCH_COMMAND "${patch_command}")
  endif()

  #
  # Configure Step Options
  #

  if(NOT "${configure_command}" STREQUAL "NOTFOUND")
    list(APPEND params CONFIGURE_COMMAND "${configure_command}")
  endif()

  #
  # Build Step Options
  #

  if(NOT "${build_command}" STREQUAL "NOTFOUND")
    list(APPEND params BUILD_COMMAND "${build_command}")
  endif()

  if(${build_in_source})
    list(APPEND params BUILD_IN_SOURCE ${build_in_source})
  endif()

  #
  # Install Step Options
  #

  if(NOT "${install_command}" STREQUAL "NOTFOUND")
    list(APPEND params INSTALL_COMMAND "${install_command}")
  endif()

  #
  # Test Step Options
  #

  if(NOT "${test_command}" STREQUAL "NOTFOUND")
    list(APPEND params TEST_COMMAND "${test_command}")
  endif()

  #
  # Target Options
  #

  if(NOT "${depends}" STREQUAL "NOTFOUND")
    list(APPEND params DEPENDS ${depends})
  endif()

  #
  # ---
  #

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
# script mode
#

function(extract_cli_arguments result)
  set(append FALSE)
  foreach(idx RANGE ${CMAKE_ARGC})
    if(${append})
      list(APPEND arguments "${CMAKE_ARGV${idx}}")
    endif()
    if("${CMAKE_ARGV${idx}}" STREQUAL "--")
      set(append TRUE)
    endif()
  endforeach()
  set(${result} ${arguments} PARENT_SCOPE)
endfunction()

function(extract_method_arguments result arguments ignore)
  foreach(arg IN ITEMS ${arguments})
    if("${arg}" MATCHES "^--(.*)=(.*)$")
      set(key "${CMAKE_MATCH_1}")
      set(val "${CMAKE_MATCH_2}")

      if("${key}" IN_LIST ignore)
        continue()
      endif()

      string(REGEX REPLACE "[-. \t]" "_" key "${key}")
      string(TOUPPER "${key}" key)

      string(TOLOWER "${val}" tmp)
      if("${tmp}" STREQUAL "true")
        set(val TRUE)
      elseif("${tmp}" STREQUAL "false")
        set(val FALSE)
      endif()

      list(APPEND args ${key} "${val}")
    endif()
  endforeach()
  set(${result} ${args} PARENT_SCOPE)
endfunction()

macro(_CMP_RUN_AS_SCRIPT)
  extract_cli_arguments(arguments)
  message(TRACE "arguments: ${arguments}")

  # first param is the command
  list(POP_FRONT arguments method)
  string(REPLACE "-" "_" method "${method}")
  message(TRACE "method: ${method}, arguments: ${arguments}")
  extract_method_arguments(method_arguments "${arguments}" "")

  message(TRACE "method: ${method}")
  message(TRACE "method_args: ${method_arguments}")

  cmake_language(CALL _cmp_${method} ${method_arguments})
endmacro()

function(_cmp_get_recipe)
  set(oneValueArgs RECIPE URL LOCAL_PATH)
  cmake_parse_arguments(ARG "" "${oneValueArgs}" "" ${ARGN})

  if(DEFINED ARG_RECIPE)
    set(recipe "${ARG_RECIPE}")
  else()
    message(FATAL_ERROR "no recipe specified (use --recipe=<recipe>)")
  endif()

  if(DEFINED ARG_URL)
    set(url "${ARG_URL}")
  else()
    set(url "https://raw.githubusercontent.com/ngruenwald/cmake-project/main/recipes/")
  endif()

  if(DEFINED ARG_LOCAL_PATH)
    set(local_path "${ARG_LOCAL_PATH}")
  else()
    set(local_path "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/recipes")
  endif()

  set(url "${url}/${recipe}")

  set(local_file "${local_path}/${recipe}")
  set(local_temp "${local_file}.tmp")

  file(DOWNLOAD "${url}" "${local_temp}" STATUS status)
  list(GET status 0 code)
  if(${code} EQUAL 0)
    file(RENAME "${local_temp}" "${local_file}")
    message("downloaded recipe '${recipe}' to '${local_file}'")
  else()
    file(REMOVE "${local_temp}")
    list(GET status 1 message)
    message(FATAL_ERROR "could not download recipe '${recipe}': ${message} (${code})")
  endif()
endfunction()

#
# module mode
#

macro(_CMP_RUN_AS_MODULE)
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
        message(FATAL_ERROR ${CM_MESSAGE_PREFIX} "no suitable cmake project file found in '${rootdir}'")
      endif()
    endmacro()
    _cmp_search_and_load(${CMAKE_SOURCE_DIR})
  endif()

  message(DEBUG "using recipes from \"${CMAKE_PROJECT_DEFAULT_RECIPE_PATH}\"")
  if(NOT "${CMAKE_PROJECT_REMOTE_RECIPE_PATH}" STREQUAL "" AND
      NOT "${CMAKE_PROJECT_REMOTE_RECIPE_PATH}" STREQUAL "${CMAKE_PROJECT_DEFAULT_RECIPE_PATH}")
    message(DEBUG "using additional recipes from \"${CMAKE_PROJECT_REMOTE_RECIPE_PATH}\"")
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

    _cmp_set_project_vars()

    cmp_find_project_dependencies()
  endif()
endmacro()

#
# auto-magic
#

if(CMAKE_SCRIPT_MODE_FILE AND NOT CMAKE_PARENT_LIST_FILE)
  _CMP_RUN_AS_SCRIPT()
else()
  _CMP_RUN_AS_MODULE()
endif()
