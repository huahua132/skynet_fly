package = "basexx"
version = "0.1.1-1"
description = {
   summary  = "A base2, base32 and base64 library for Lua",
   detailed = "A library which provides base2(bitfield), base32(crock ford/rfc 3548), base64 decoding and encoding.",
   license  = "MIT",
   homepage = "https://github.com/aiq/basexx"
}
dependencies = {
   "lua >= 5.1"
}
source = {
   url = "https://github.com/aiq/basexx/archive/v0.1.1.tar.gz",
   md5 = "6481b5f980c0da1248821273271290be",
   dir = "basexx-0.1.1"
}
build = {
   type = 'builtin',
   modules = {
      basexx = "lib/basexx.lua"
   },
   copy_directories = { "test" }
}