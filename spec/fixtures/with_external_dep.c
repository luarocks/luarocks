#include <foo/foo.h>
#include <lua.h>
#include <lauxlib.h>

int luaopen_with_external_dep(lua_State* L) {
   lua_newtable(L);
   lua_pushinteger(L, FOO);
   lua_setfield(L, -2, "foo");
   return 1;
}
