package = "LuaSocket"
version = "2.0.2-3"
source = {
   url = "http://luaforge.net/frs/download.php/2664/luasocket-2.0.2.tar.gz",
   md5 = "41445b138deb7bcfe97bff957503da8e"
}
description = {
   summary = "Network support for the Lua language",
   detailed = [[
      LuaSocket is a Lua extension library that is composed by two parts: a C core
      that provides support for the TCP and UDP transport layers, and a set of Lua
      modules that add support for functionality commonly needed by applications
      that deal with the Internet.
   ]]
}
build = {
   type = "make",
   build_variables = {
      CFLAGS = "$(CFLAGS) -DLUASOCKET_DEBUG -I$(LUA_INCDIR)",
      LDFLAGS = "$(LIBFLAG) -O -fpic",
      LD = "$(CC)"
   },
   install_variables = {
      INSTALL_TOP_SHARE = "$(LUADIR)",
      INSTALL_TOP_LIB = "$(LIBDIR)"
   },
   platforms = {
      macosx = {
         build_variables = {
            CFLAGS = "$(CFLAGS) -DLUASOCKET_DEBUG -DUNIX_HAS_SUN_LEN -fno-common -I$(LUA_INCDIR)"
         }
      }
   }
}
