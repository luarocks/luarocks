package = "LuaZip"
version = "1.2.3-2"
source = {
   url = "http://luaforge.net/frs/download.php/2493/luazip-1.2.3.tar.gz"
}
description = {
   summary = "Library for reading files inside zip files",
   detailed = [[
      LuaZip is a lightweight Lua extension library used to read files
      stored inside zip files. The API is very similar to the standard
      Lua I/O library API.
   ]],
   license = "MIT/X11",
   homepage = "http://www.keplerproject.org/luaexpat/"
}
dependencies = {
   "lua >= 5.1"
}
external_dependencies = {
   ZZIP = {
      header = "zzip.h"
   }
}
build = {
   type = "make",
   variables = {
      LUA_VERSION_NUM="501",
   },
   build_variables = {
      LIB_OPTION = "$(LIBFLAG) -L$(ZZIP_LIBDIR)",
      CFLAGS = "$(CFLAGS) -I$(LUA_INCDIR) -I$(ZZIP_INCDIR)",
   },
   install_variables = {
      LUA_LIBDIR = "$(LIBDIR)",
      LUA_DIR = "$(LUADIR)"
   }
}
