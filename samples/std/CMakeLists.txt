cmake_minimum_required(VERSION 3.28...4.4)

project(ClangProfileSample VERSION 1.0.0 LANGUAGES CXX)

add_library(ClangProfileWarnings INTERFACE)
if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
  target_compile_options(ClangProfileWarnings INTERFACE /W4 /permissive- /Zc:__cplusplus)
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  target_compile_options(ClangProfileWarnings INTERFACE -Wall -Wextra -Wpedantic)
endif()

add_library(ClangProfileSample STATIC Sample.cpp)
target_include_directories(
  ClangProfileSample
  PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
)
target_compile_features(ClangProfileSample PUBLIC cxx_std_23)
target_link_libraries(ClangProfileSample PRIVATE ClangProfileWarnings)
set_target_properties(ClangProfileSample PROPERTIES CXX_EXTENSIONS OFF)

include(CTest)
if(BUILD_TESTING)
  add_executable(ClangProfileSampleTest SampleTest.cpp)
  target_link_libraries(ClangProfileSampleTest PRIVATE ClangProfileSample ClangProfileWarnings)
  set_target_properties(ClangProfileSampleTest PROPERTIES CXX_EXTENSIONS OFF)
  add_test(NAME ClangProfileSampleTest COMMAND ClangProfileSampleTest)
endif()
