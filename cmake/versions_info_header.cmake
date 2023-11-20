
function(create_versions_h target)
  set(input_filename "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/versions_info_header/versions.h.in")
  set(output_filename "${CMAKE_CURRENT_BINARY_DIR}/versions.h")

  _get_formatted_project_dependencies(project_dependencies project_dependencies_count ${CM_PROJECT_DEPENDENCIES})
  _get_formatted_target_dependencies(target_dependencies target_dependencies_count ${target})
  file(READ "${input_filename}" template)
  file(CONFIGURE OUTPUT "${output_filename}" CONTENT "${template}")
endfunction()


function(create_versions_hpp target)
  set(input_filename "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/versions_info_header/versions.hpp.in")
  set(output_filename "${CMAKE_CURRENT_BINARY_DIR}/versions.hpp")

  _get_formatted_project_dependencies(project_dependencies project_dependencies_count "${CM_PROJECT_DEPENDENCIES}")
  _get_formatted_target_dependencies(target_dependencies target_dependencies_count ${target})
  file(READ "${input_filename}" template)
  file(CONFIGURE OUTPUT "${output_filename}" CONTENT "${template}")
endfunction()


function(_get_formatted_target_dependencies result count target)
  set(tmp "")

  get_target_property(deps ${target} LINK_LIBRARIES)
  list(LENGTH deps len)

  foreach(dep IN ITEMS ${deps})
    get_target_property(version ${dep} VERSION)
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
