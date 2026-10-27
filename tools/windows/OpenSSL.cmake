# Private fsnet build-copy replacement, never changes the user's fsnet checkout.
include(ExternalProject)
find_package(Perl REQUIRED)
find_program(FSNET_MAKE_EXECUTABLE NAMES gmake make REQUIRED)
if(NOT WIN32 OR NOT EXISTS "${AMBER_OPENSSL_SOURCE}/Configure")
  message(FATAL_ERROR "Windows x86_64 and a preverified local OpenSSL source are required")
endif()
set(FSNET_CRYPTO_ROOT "${CMAKE_BINARY_DIR}/openssl-install")
file(MAKE_DIRECTORY "${FSNET_CRYPTO_ROOT}/include")
ExternalProject_Add(fsnet-openssl
  SOURCE_DIR "${AMBER_OPENSSL_SOURCE}"
  DOWNLOAD_COMMAND "" UPDATE_COMMAND ""
  CONFIGURE_COMMAND ${PERL_EXECUTABLE} <SOURCE_DIR>/Configure mingw64
    --cross-compile-prefix=x86_64-w64-mingw32- --prefix=${FSNET_CRYPTO_ROOT} --libdir=lib
    no-shared no-tests no-module no-legacy -fPIC
  BUILD_COMMAND ${FSNET_MAKE_EXECUTABLE} -j4 build_libs
  INSTALL_COMMAND ${FSNET_MAKE_EXECUTABLE} install_dev
  BUILD_BYPRODUCTS ${FSNET_CRYPTO_ROOT}/lib/libssl.a ${FSNET_CRYPTO_ROOT}/lib/libcrypto.a
  LOG_CONFIGURE ON LOG_BUILD ON LOG_INSTALL ON)
add_library(fsnet-crypto STATIC IMPORTED GLOBAL)
set_target_properties(fsnet-crypto PROPERTIES IMPORTED_LOCATION "${FSNET_CRYPTO_ROOT}/lib/libcrypto.a"
  INTERFACE_INCLUDE_DIRECTORIES "${FSNET_CRYPTO_ROOT}/include"
  INTERFACE_LINK_LIBRARIES "Threads::Threads;ws2_32;crypt32")
add_dependencies(fsnet-crypto fsnet-openssl)
add_library(fsnet-ssl STATIC IMPORTED GLOBAL)
set_target_properties(fsnet-ssl PROPERTIES IMPORTED_LOCATION "${FSNET_CRYPTO_ROOT}/lib/libssl.a"
  INTERFACE_INCLUDE_DIRECTORIES "${FSNET_CRYPTO_ROOT}/include"
  INTERFACE_LINK_LIBRARIES fsnet-crypto)
add_dependencies(fsnet-ssl fsnet-openssl)
