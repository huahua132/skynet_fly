cmake_minimum_required(VERSION 3.0 FATAL_ERROR)
project(libprov LANGUAGES C)
set(CMAKE_C_STANDARD 99)

if (NOT OPENSSL_FOUND)
  find_package(OpenSSL 3.0 REQUIRED)
endif()

add_library(libprov STATIC err.c)
set_target_properties(libprov PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  OUTPUT_NAME "prov")
target_include_directories(libprov PUBLIC include)
target_link_libraries(libprov PRIVATE OpenSSL::Crypto)
