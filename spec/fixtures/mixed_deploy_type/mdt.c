#include "lua.h"

int luaopen_mdt(lua_State *L) {
   lua_pushstring(L, "mdt.c");
   return 1;
}
