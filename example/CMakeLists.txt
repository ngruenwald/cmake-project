cmake_minimum_required(VERSION 3.20)
include(../cmake/cmake_project.cmake)

project(${CM_PROJECT_PARAMS})

add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} fmt::fmt)
target_link_libraries(${PROJECT_NAME} OpenSSL::Crypto)
