package = "basexx"
version = "scm-0"

description = {
   summary  = "A base2, base16, base32, base64 and base85 library for Lua",
   detailed = "A Lua library which provides base2(bitfield), base16(hex), base32(crockford/rfc), base64(rfc/url), base85(z85) decoding and encoding.",
   license  = "MIT",
   homepage = "https://github.com/aiq/basexx"
}

source = {
   url = "..."
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
