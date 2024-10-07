if (OQS_PROVIDER_BUILD_STATIC)
  add_executable(example_static_oqsprovider static_oqsprovider.c)
  target_link_libraries(example_static_oqsprovider PRIVATE ${OPENSSL_CRYPTO_LIBRARY} oqsprovider)
  targets_set_static_provider(example_static_oqsprovider)
  add_test(NAME test_example_static_oqsprovider
    COMMAND example_static_oqsprovider)
endif()
