package = "MD5"
version = "1.1.2-1"
source = {
   url = ""
}
description = {
   summary = "Basic cryptographic library",
   detailed = [[
      MD5 offers basic cryptographic facilities for Lua 5.1:
      a hash (digest) function, a pair crypt/decrypt based on MD5 and CFB,
      and a pair crypt/decrypt based on DES with 56-bit keys.
   ]],
   license = "MIT/X11",
   homepage = "http://www.keplerproject.org/md5/"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "make",
   variables = {
      LUA_VERSION_NUM="501",
   },
   build_variables = {
     LIB_OPTION = "$(LIBFLAG)",
     CFLAGS = "$(CFLAGS) -I$(LUA_INCDIR)",
   },
   install_variables = {
      LUA_LIBDIR = "$(LIBDIR)",
      LUA_DIR = "$(LUADIR)"
   },
   platforms = {
     win32 = {
       build_variables = {
	 LUA_LIB = "$(LUA_LIBDIR)\\lua5.1.lib"
       }
     }
   }
}
