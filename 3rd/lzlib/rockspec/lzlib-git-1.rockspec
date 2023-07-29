package="lzlib"
version="git-1"
source = {
   url = "git://github.com/LuaDist/lzlib.git",
   branch = "master",
}
description = {
   summary = "Lua bindings to the ZLib compression library",
   detailed = [[
      This package provides a library to access zlib library functions
      and also to read/write gzip files using an interface similar
      to the base io package.
   ]],
   homepage = "http://luaforge.net/projects/lzlib/",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1"
}
external_dependencies = {
   ZLIB = {
      header = "zlib.h",
      library = "z",
   }
}
build = {
   type = "builtin",
   modules = {
      zlib = {
         sources = "lzlib.c",
         libdirs = "$(ZLIB_LIBDIR)",
         incdirs = "$(ZLIB_INCDIR)",
         libraries = "z",
      },
      gzip = "gzip.lua",
   }
}
