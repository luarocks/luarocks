SUITE: luarocks-admin make_manifest

================================================================================
TEST: runs

FILE: test-1.0-1.rockspec
--------------------------------------------------------------------------------
package = "test"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/test.lua"
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

RUN: luarocks make --pack-binary-rock ./test-1.0-1.rockspec

RUN: luarocks-admin make_manifest .

FILE_CONTENTS: ./manifest-%{lua_version}
--------------------------------------------------------------------------------
commands = {}
modules = {}
repository = {
   test = {
      ["1.0-1"] = {
         {
            arch = "all"
         },
         {
            arch = "rockspec"
         }
      }
   }
}
--------------------------------------------------------------------------------
