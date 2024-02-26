================================================================================
TEST: luarocks path: --project-tree


RUN: luarocks path --project-tree=foo
STDOUT:
--------------------------------------------------------------------------------
%{path(foo/share/lua/%{lua_version}/?.lua)}
%{path(foo/share/lua/%{lua_version}/?/init.lua)}
--------------------------------------------------------------------------------

RUN: luarocks path --project-tree=foo --tree=bar
NOT_STDOUT:
--------------------------------------------------------------------------------
%{path(foo/share/lua/%{lua_version}/?.lua)}
%{path(foo/share/lua/%{lua_version}/?/init.lua)}
--------------------------------------------------------------------------------
STDOUT:
--------------------------------------------------------------------------------
%{path(bar/share/lua/%{lua_version}/?.lua)}
%{path(bar/share/lua/%{lua_version}/?/init.lua)}
--------------------------------------------------------------------------------
