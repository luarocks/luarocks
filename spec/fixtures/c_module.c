#include <lua.h>
#include <lauxlib.h>

int luaopen_c_module(lua_State* L) {
  lua_newtable(L);
  lua_pushinteger(L, 1);
  lua_setfield(L, -2, "c_module");
  return 1;
}
