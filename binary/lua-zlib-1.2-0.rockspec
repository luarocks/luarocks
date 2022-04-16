package = "lua-zlib"
version = "1.2-0"
source = {
   url = "git+https://github.com/brimworks/lua-zlib.git",
   tag = "v1.2",
}
description = {
   summary = "Simple streaming interface to zlib for Lua.",
   detailed = [[
      Simple streaming interface to zlib for Lua.
      Consists of two functions: inflate and deflate.
      Both functions return "stream functions" (takes a buffer of input and returns a buffer of output).
      This project is hosted on github.
   ]],
   homepage = "https://github.com/brimworks/lua-zlib",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, <= 5.4"
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
         sources = { "lua_zlib.c" },
         libraries = { "z" },
         defines = { "LZLIB_COMPAT" },
         incdirs = { "$(ZLIB_INCDIR)" },
         libdirs = { "$(ZLIB_LIBDIR)" },
      }
   },
}
