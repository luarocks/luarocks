================================================================================
TEST: luarocks config --system-config shows the path of the system config

MKDIR: %{testing_lrprefix}/etc/luarocks

FILE: %{testing_lrprefix}/etc/luarocks/config-%{LUA_VERSION}.lua
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

RUN: luarocks config --system-config

STDOUT:
--------------------------------------------------------------------------------
%{testing_lrprefix}/etc/luarocks/config-%{LUA_VERSION}.lua
--------------------------------------------------------------------------------
#TODO: ^^^ %{path()}
