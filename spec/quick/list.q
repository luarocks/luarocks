SUITE: luarocks list

================================================================================
TEST: invalid tree

RUN: luarocks --tree=%{path(/some/invalid/tree)} list

STDOUT:
--------------------------------------------------------------------------------
Rocks installed for Lua %{lua_version} in %{path(/some/invalid/tree)}
--------------------------------------------------------------------------------



================================================================================
TEST: --porcelain

FILE: a_rock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "a_rock"
version = "1.0-1"
source = {
   url = "file://%{url(%{fixtures_dir})}/a_rock.lua"
}
description = {
   summary = "An example rockspec",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   modules = {
      build = "a_rock.lua"
   },
}
--------------------------------------------------------------------------------
RUN: luarocks build a_rock-1.0-1.rockspec

RUN: luarocks list --porcelain

STDOUT:
--------------------------------------------------------------------------------
a_rock	1.0-1	installed	%{testing_sys_rocks}
--------------------------------------------------------------------------------
