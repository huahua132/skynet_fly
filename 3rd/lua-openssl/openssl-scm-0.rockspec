package = "openssl"
version = "scm-0"
rockspec_format = "3.0"

source = {
  url = "https://github.com/zhaozg/lua-openssl/archive/master.zip"
}

description = {
  summary    = "Openssl binding for Lua",
  homepage   = "https://github.com/zhaozg/lua-openssl",
  license    = "MIT",
  maintainer = "George Zhao",
  detailed   = [[
Full openssl bindings for luajit and lua 5.1/5.2/5.3/5.4.

This library makes openssl available to lua scripts.
  ]],
}

dependencies = {
  "lua >= 5.1, <= 5.4"
}

external_dependencies = {
  OPENSSL = {
    header = "openssl/evp.h"
  }
}

build = {
  type = "builtin",

  modules = {
    openssl = {
      sources = {
        "deps/auxiliar/auxiliar.c",
        "deps/auxiliar/subsidiar.c",
        "src/asn1.c",
        "src/bio.c",
        "src/callback.c",
        "src/cipher.c",
        "src/cms.c",
        "src/compat.c",
        "src/crl.c",
        "src/csr.c",
        "src/dh.c",
        "src/digest.c",
        "src/dsa.c",
        "src/ec.c",
        "src/engine.c",
        "src/mac.c",
        "src/hmac.c",
        "src/lbn.c",
        "src/lhash.c",
        "src/misc.c",
        "src/ocsp.c",
        "src/openssl.c",
        "src/ots.c",
        "src/pkcs7.c",
        "src/pkcs12.c",
        "src/pkey.c",
        "src/rsa.c",
        "src/srp.c",
        "src/ssl.c",
        "src/th-lock.c",
        "src/util.c",
        "src/x509.c",
        "src/xalgor.c",
        "src/xattrs.c",
        "src/xexts.c",
        "src/xname.c",
        "src/xstore.c"
      },
      incdirs = {"$(OPENSSL_DIR)/include", "deps/auxiliar", "deps/lua-compat/c-api"},
      defines = {},
      libraries = {"ssl", "crypto"},
    }
  },

  platforms = {
    windows = {
      modules = {
        openssl = {
          libraries = {"libeay32", "ssleay32", "ws2_32", "kernel32", "user32", "gdi32", "advapi32"},
          defines = {"LUA_BUILD_AS_DLL", "LUA_LIB", "WIN32_LEAN_AND_MEAN"},
          incdirs = {"$(OPENSSL_DIR)/include"},
          libdirs = {"$(OPENSSL_DIR)/lib"},
        }
      }
    },
    linux = {
      modules = {
        openssl = {
          incdirs = {"$(OPENSSL_DIR)/include"},
          libdirs = {"$(OPENSSL_DIR)/lib"},
        }
      }
    },
    macosx = {
      modules = {
        openssl = {
          incdirs = {"$(OPENSSL_DIR)/include"},
          libdirs = {"$(OPENSSL_DIR)/lib"},
        }
      }
    }
  },
}

test = {
  type = "command",
  command = "LUA=`luarocks config deploy_bin_dir`/`luarocks config lua_interpreter` && cd test && $LUA test.lua"
}
