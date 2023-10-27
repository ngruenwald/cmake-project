# https://github.com/ngruenwald/kubus-cmake

#
# cmp_kubus(name data)
#
# Find and install dependency via kubus_find_package
#
# @param[in] name   Name of the dependency
# @param[in] data   Additional parameters
#
function(cmp_kubus name data)
  _cmp_get_opt(version  "${data}"   "version"   "")
  _cmp_get_opt(force    "${data}"   "force"     OFF)
  _cmp_get_opt(exact    "${data}"   "exact"     OFF)
  _cmp_get_opt(quiet    "${data}"   "quiet"     OFF)
  _cmp_get_opt(required "${data}"   "required"  OFF)
  _cmp_get_opt(server   "${data}"   "server"    "${KUBUS_SERVER}")

  string(JSON data_type TYPE "${data}")
  if("${data_type}" STREQUAL "STRING" OR "${data_type}" STREQUAL "NUMBER")
    set(version "${data}")
  endif()

  if(${force})
    list(APPEND params FORCE)
  endif()
  if(${exact})
    list(APPEND params EXACT)
  endif()
  if(${quiet})
    list(APPEND params QUIET)
  endif()
  if(${required})
    list(APPEND params REQUIRED)
  endif()

  set(KUBUS ON)

  if(NOT "${server}" STREQUAL "")
    set(KUBUS_SERVER "${server}")
  endif()

  include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/kubus.cmake)
  kubus_find_package("${name}" "${version}" ${params})
endfunction()
