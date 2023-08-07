package = "basexx"
version = "0.1.0-1"
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
   url = "https://github.com/aiq/basexx/archive/v0.1.0.tar.gz",
   md5 = "66570a1e354ce0c919192c895a1ee8bb",
   dir = "basexx-0.1.0"
}
build = {
   type = 'builtin',
   modules = {
      basexx = "lib/basexx.lua"
   },
   copy_directories = { "test" }
}