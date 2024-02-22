===============================================================================
TEST: luarocks install: handle versioned modules when installing another version with --keep #268

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(tmpdir)}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: myrock-2.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "2.0-1"
source = {
   url = "file://%{url(tmpdir)}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

RUN: luarocks build myrock-1.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks build myrock-2.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks install ./myrock-2.0-1.all.rock

EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/rock.lua

RUN: luarocks install ./myrock-1.0-1.all.rock --keep

EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/rock.lua
EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/myrock_1_0_1-rock.lua

RUN: luarocks install ./myrock-2.0-1.all.rock

EXISTS:     %{testing_sys_tree}/share/lua/%{LUA_VERSION}/rock.lua
NOT_EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/myrock_1_0_1-rock.lua



===============================================================================
TEST: luarocks install: handle versioned libraries when installing another version with --keep #268

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(tmpdir)}/c_module.c"
}
build = {
   modules = {
      c_module = { "c_module.c" }
   }
}
--------------------------------------------------------------------------------

FILE: myrock-2.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "2.0-1"
source = {
   url = "file://%{url(tmpdir)}/c_module.c"
}
build = {
   modules = {
      c_module = { "c_module.c" }
   }
}
--------------------------------------------------------------------------------
FILE: c_module.c
--------------------------------------------------------------------------------
#include <lua.h>
#include <lauxlib.h>

int luaopen_c_module(lua_State* L) {
  lua_newtable(L);
  lua_pushinteger(L, 1);
  lua_setfield(L, -2, "c_module");
  return 1;
}
--------------------------------------------------------------------------------

RUN: luarocks build myrock-1.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks build myrock-2.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks install ./myrock-2.0-1.%{platform}.rock

EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/c_module.%{lib_extension}

RUN: luarocks install ./myrock-1.0-1.%{platform}.rock --keep

EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/c_module.%{lib_extension}
EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/myrock_1_0_1-c_module.%{lib_extension}

RUN: luarocks install ./myrock-2.0-1.%{platform}.rock

EXISTS:     %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/c_module.%{lib_extension}
NOT_EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/myrock_1_0_1-c_module.%{lib_extension}
