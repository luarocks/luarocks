SUITE: luarocks config

================================================================================
TEST: --system-config shows the path of the system config

FILE: %{testing_lrprefix}/etc/luarocks/config-%{LUA_VERSION}.lua
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
RUN: luarocks config --system-config

STDOUT:
--------------------------------------------------------------------------------
%{path(%{testing_lrprefix}/etc/luarocks/config-%{LUA_VERSION}.lua)}
--------------------------------------------------------------------------------



================================================================================
TEST: reports when setting a bad LUA_LIBDIR

RUN: luarocks config variables.LUA_LIBDIR /some/bad/path

LuaRocks writes configuration values as they are given, without auto-conversion
of slashes for Windows:

STDOUT:
--------------------------------------------------------------------------------
Wrote
variables.LUA_LIBDIR = "/some/bad/path"
--------------------------------------------------------------------------------

STDERR:
--------------------------------------------------------------------------------
Warning: Failed finding the Lua library.
Tried:

LuaRocks may not work correctly when building C modules using this configuration.
--------------------------------------------------------------------------------



================================================================================
TEST: reports when setting a bad LUA_INCDIR

RUN: luarocks config variables.LUA_INCDIR /some/bad/path

STDOUT:
--------------------------------------------------------------------------------
Wrote
variables.LUA_INCDIR = "/some/bad/path"
--------------------------------------------------------------------------------

LuaRocks uses configuration values as they are given, without auto-conversion
of slashes for Windows:

STDERR:
--------------------------------------------------------------------------------
Warning: Failed finding Lua header lua.h (searched at /some/bad/path). You may need to install Lua development headers.

LuaRocks may not work correctly when building C modules using this configuration.
--------------------------------------------------------------------------------



================================================================================
TEST: rejects setting bad lua_dir

RUN: luarocks config lua_dir /some/bad/dir
EXIT: 1

STDERR:
--------------------------------------------------------------------------------
Lua interpreter not found
--------------------------------------------------------------------------------



================================================================================
TEST: reports when setting a bad LUA_INCDIR

RUN: luarocks config variables.LUA_INCDIR /some/bad/path

STDOUT:
--------------------------------------------------------------------------------
Wrote
variables.LUA_INCDIR = "/some/bad/path"
--------------------------------------------------------------------------------

LuaRocks uses configuration values as they are given, without auto-conversion
of slashes for Windows:

STDERR:
--------------------------------------------------------------------------------
Warning: Failed finding Lua header lua.h (searched at /some/bad/path). You may need to install Lua development headers.

LuaRocks may not work correctly when building C modules using this configuration.
--------------------------------------------------------------------------------
