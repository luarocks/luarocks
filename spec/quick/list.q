================================================================================
TEST: luarocks list: invalid tree

RUN: luarocks --tree=%{path(/some/invalid/tree)} list

STDOUT:
--------------------------------------------------------------------------------
Rocks installed for Lua %{lua_version} in /some/invalid/tree
--------------------------------------------------------------------------------
#TODO:                                    ^^^ %{path()}
