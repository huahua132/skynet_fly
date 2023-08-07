package = "basexx"
version = "0.3.0-1"

description = {
   summary  = "A base2, base16, base32, base64 and base85 library for Lua",
   detailed = "A Lua library which provides base2(bitfield), base16(hex), base32(crockford/rfc), base64(rfc/url), base85(z85) decoding and encoding.",
   license  = "MIT",
   homepage = "https://github.com/aiq/basexx"
}

source = {
   url = "https://github.com/aiq/basexx/archive/v0.3.0.tar.gz",
   md5 = "32277d2c4564dabd0c45c9c67ec1e811",
   dir = "basexx-0.3.0"
}

dependencies = {
   "lua >= 5.1"
}

build = {
   type = 'builtin',
   modules = {
      basexx = "lib/basexx.lua"
   },
   copy_directories = { "test" }
}
