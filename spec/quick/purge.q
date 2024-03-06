SUITE: luarocks purge

================================================================================
TEST: needs a --tree argument
RUN: luarocks purge
EXIT: 1

================================================================================
TEST: missing tree
RUN: luarocks purge --tree=missing-tree
EXIT: 1

================================================================================
TEST: missing --tree argument
RUN: luarocks purge --tree=
EXIT: 1


================================================================================
TEST: runs

FILE: testrock-1.0-1.rockspec
--------------------------------------------------------------------------------
package = "testrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/testrock.lua"
}
dependencies = {
   "a_rock >= 0.8"
}
build = {
   type = "builtin",
   modules = {
      testrock = "testrock.lua"
   }
}
--------------------------------------------------------------------------------

FILE: testrock.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

RUN: luarocks build --only-server=%{fixtures_dir}/a_repo testrock-1.0-1.rockspec

EXISTS: %{testing_sys_rocks}/testrock
EXISTS: %{testing_sys_rocks}/a_rock

RUN: luarocks purge --tree=%{testing_sys_tree}

NOT_EXISTS: %{testing_sys_rocks}/testrock
NOT_EXISTS: %{testing_sys_rocks}/a_rock



================================================================================
TEST: works with missing files

FILE: testrock-1.0-1.rockspec
--------------------------------------------------------------------------------
package = "testrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/testrock.lua"
}
dependencies = {
   "a_rock >= 0.8"
}
build = {
   type = "builtin",
   modules = {
      testrock = "testrock.lua"
   }
}
--------------------------------------------------------------------------------

FILE: testrock.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

RUN: luarocks build --only-server=%{fixtures_dir}/a_repo testrock-1.0-1.rockspec

RMDIR: %{testing_sys_tree}/share/lua/%{lua_version}/testrock

RUN: luarocks purge --tree=%{testing_sys_tree}

NOT_EXISTS: %{testing_sys_rocks}/testrock
NOT_EXISTS: %{testing_sys_rocks}/a_rock



================================================================================
TEST: --old-versions

RUN: luarocks install --only-server=%{fixtures_dir}/a_repo a_rock 2.0
RUN: luarocks install --only-server=%{fixtures_dir}/a_repo a_rock 1.0 --keep

RUN: luarocks purge --old-versions --tree=%{testing_sys_tree}

EXISTS: %{testing_sys_rocks}/a_rock/2.0-1
NOT_EXISTS: %{testing_sys_rocks}/a_rock/1.0-1
