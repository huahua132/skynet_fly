include(GNUInstallDirs)
execute_process(
  COMMAND git log -1 --format=%h
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_COMMIT_HASH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
if (USE_ENCODING_LIB)
  include(ExternalProject)
  set(encoder_LIBRARY ${CMAKE_BINARY_DIR}/install/lib/${CMAKE_STATIC_LIBRARY_PREFIX}qsc_key_encoder${CMAKE_STATIC_LIBRARY_SUFFIX})
  set(encoder_LIBRARY_INCLUDE ${CMAKE_BINARY_DIR}/install/include)
  ExternalProject_Add(encoder
      GIT_REPOSITORY https://github.com/Quantum-Safe-Collaboration/qsc-key-encoder.git
      GIT_TAG main
      CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/install -DCMAKE_BUILD_TYPE=Release
      UPDATE_DISCONNECTED 1
      BUILD_BYPRODUCTS ${encoder_LIBRARY}
  )
  add_library(qsc_key_encoder STATIC IMPORTED)
  set_target_properties(qsc_key_encoder PROPERTIES IMPORTED_LOCATION ${encoder_LIBRARY})
endif()
add_definitions(-DOQSPROVIDER_VERSION_TEXT="${OQSPROVIDER_VERSION_TEXT}")
message(STATUS "Building commit ${GIT_COMMIT_HASH} in ${CMAKE_SOURCE_DIR}")
add_definitions(-DOQS_PROVIDER_COMMIT=" \(${GIT_COMMIT_HASH}\)")
set(PROVIDER_SOURCE_FILES
  oqsprov.c oqsprov_capabilities.c oqsprov_keys.c
  oqs_kmgmt.c oqs_sig.c oqs_kem.c
  oqs_encode_key2any.c oqs_endecoder_common.c oqs_decode_der2key.c oqsprov_bio.c
  oqsprov.def
)
set(PROVIDER_HEADER_FILES
  oqs_prov.h oqs_endecoder_local.h
)

set(OQS_LIBRARY_TYPE MODULE)
if(OQS_PROVIDER_BUILD_STATIC)
  set(OQS_LIBRARY_TYPE STATIC)
endif()

add_library(oqsprovider ${OQS_LIBRARY_TYPE} ${PROVIDER_SOURCE_FILES})
if (USE_ENCODING_LIB)
  add_dependencies(oqsprovider encoder)
endif()
set_target_properties(oqsprovider
    PROPERTIES
    PREFIX ""
    OUTPUT_NAME "oqsprovider"
    PUBLIC_HEADER "oqs_prov.h"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    VERSION ${OQSPROVIDER_VERSION_TEXT}
    SOVERSION 1
    # Compatibility version (-compatibility_version) and current version
    # (-current_version) are not compatible with a `MODULE` library.
    # However, `VERSION` and `SOVERSION` set these two flags.
    # The following two flags remove them.
    MACHO_COMPATIBILITY_VERSION OFF
    MACHO_CURRENT_VERSION OFF
    # For Windows DLLs
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

if (NOT OQS_PROVIDER_BUILD_STATIC)
  if (APPLE)
    # OpenSSL looks for `.dylib` files on XNU-based platforms.
    # Because `MODULE` writes to a `.so` file by default, we must explicitely
    # set the suffix here.
    set_target_properties(oqsprovider
      PROPERTIES
      SUFFIX ".dylib"
    )
  endif()

  if (CYGWIN OR MSVC)
    # OpenSSL looks for `.dll` files on Windows platforms.
    # Because `MODULE` writes to a `.so` file by default, we must explicitely
    # set the suffix here.
    set_target_properties(oqsprovider
      PROPERTIES
      SUFFIX ".dll"
    )
  endif()
endif()

target_link_libraries(oqsprovider PUBLIC OQS::oqs ${OPENSSL_CRYPTO_LIBRARY} ${OQS_ADDL_SOCKET_LIBS})
if (USE_ENCODING_LIB)
  target_link_libraries(oqsprovider PUBLIC qsc_key_encoder)
  target_include_directories(oqsprovider PRIVATE ${encoder_LIBRARY_INCLUDE})
endif()
install(TARGETS oqsprovider
        CONFIGURATIONS Debug Release
        LIBRARY DESTINATION "${OPENSSL_MODULES_PATH}"
        RUNTIME DESTINATION "${OPENSSL_MODULES_PATH}")

if ("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "aarch64")
  set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE arm64)
elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x86_64")
  set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE amd64)
endif()

install(TARGETS oqsprovider
        CONFIGURATIONS DebPack
        DESTINATION .
        LIBRARY DESTINATION lib/ossl-modules
        ARCHIVE DESTINATION lib/
        PUBLIC_HEADER DESTINATION include/oqs-provider/
        )
set(CPACK_GENERATOR "DEB")
set(CPACK_PACKAGE_VENDOR "www.openquantumsafe.org")
set(CPACK_PACKAGE_VERSION ${OQSPROVIDER_VERSION_TEXT})
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libc6, openssl (>= 3.0.0), liboqs (>= 0.8.0)")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "www.openquantumsafe.org")
include(CPack)

if (OQS_PROVIDER_BUILD_STATIC)
  targets_set_static_provider(oqsprovider)
endif()
