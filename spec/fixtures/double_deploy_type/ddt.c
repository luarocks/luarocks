#include "lua.h"

int luaopen_ddt(lua_State *L) {
   lua_pushstring(L, "ddt.c");
   return 1;
}
