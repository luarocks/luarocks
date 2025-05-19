package = "lua-zlib"
version = "1.2-0"
source = {
   url = "git://github.com/brimworks/lua-zlib.git",
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
   "lua >= 5.1, <= 5.3"
}
external_dependencies = {
    ZLIB = {
       header = "zlib.h"
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
      }
   },
   platforms = {
      windows = { modules = { zlib = { libraries = {
         "$(ZLIB_LIBDIR)/zlib" -- Must full path to `"zlib"`, or else will cause the `LINK : fatal error LNK1149`
      } } } }
   }
}
