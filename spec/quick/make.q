SUITE: luarocks make

================================================================================
TEST: overrides luarocks.lock with --pin #pinning

FILE: test-2.0-1.rockspec
--------------------------------------------------------------------------------
package = "test"
version = "2.0-1"
source = {
   url = "file://%{path(tmpdir)}/test.lua"
}
dependencies = {
   "a_rock >= 0.8"
}
build = {
   type = "builtin",
   modules = {
      test = "test.lua"
   }
}
--------------------------------------------------------------------------------

FILE: test.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

FILE: luarocks.lock
--------------------------------------------------------------------------------
return {
   dependencies = {
      ["a_rock"] = "1.0-1",
   }
}
--------------------------------------------------------------------------------

RUN: luarocks make --only-server=%{fixtures_dir}/a_repo --pin --tree=lua_modules

EXISTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/test/2.0-1/test-2.0-1.rockspec
EXISTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/a_rock/2.0-1/a_rock-2.0-1.rockspec

FILE_CONTENTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/test/2.0-1/luarocks.lock
--------------------------------------------------------------------------------
return {
   dependencies = {
      a_rock = "2.0-1",
      lua = "%{lua_version}-1"
   }
}
--------------------------------------------------------------------------------



================================================================================
TEST: running make twice builds twice

FILE: test-2.0-1.rockspec
--------------------------------------------------------------------------------
package = "test"
version = "2.0-1"
source = {
   url = "file://%{path(tmpdir)}/test.lua"
}
build = {
   type = "builtin",
   modules = {
      test = "test.lua"
   }
}
--------------------------------------------------------------------------------

FILE: test.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

RUN: luarocks make --only-server=%{fixtures_dir}/a_repo --pin --tree=lua_modules
STDOUT:
--------------------------------------------------------------------------------
test 2.0-1 is now installed
--------------------------------------------------------------------------------

RUN: luarocks make --only-server=%{fixtures_dir}/a_repo --pin --tree=lua_modules
STDOUT:
--------------------------------------------------------------------------------
test 2.0-1 is now installed
--------------------------------------------------------------------------------
