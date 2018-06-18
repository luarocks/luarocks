local test_env = require("spec.util.test_env")
local run = test_env.run
local get_tmp_path = test_env.get_tmp_path
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

test_env.unload_luarocks()
local lfs = require("lfs")

local extra_rocks = {
   "/validate-args-1.5.4-1.rockspec"
}

describe("LuaRocks lint tests #integration", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("LuaRocks lint with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("lint"))
   end)

   it("LuaRocks lint invalid argument", function()
      assert.is_false(run.luarocks_bool("lint invalid"))
   end)
   
   it("LuaRocks lint OK", function()
      assert.is_true(run.luarocks_bool("download --rockspec validate-args 1.5.4-1"))
      local output = run.luarocks("lint validate-args-1.5.4-1.rockspec")
      assert.are.same(output, "")
      assert.is_true(os.remove("validate-args-1.5.4-1.rockspec"))
   end)
   
   describe("LuaRocks lint mismatch set", function()
      local tmpdir
      local olddir
      
      before_each(function()
         tmpdir = get_tmp_path()
         olddir = lfs.currentdir()
         lfs.mkdir(tmpdir)
         lfs.chdir(tmpdir)
      end)
      
      after_each(function()
         if olddir then
            lfs.chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir)
            end
         end
      end)
      
      it("LuaRocks lint mismatch string", function()
         write_file("type_mismatch_string-1.0-1.rockspec", [[
            package="type_mismatch_version"
            version=1.0
         ]], finally)
         assert.is_false(run.luarocks_bool("lint type_mismatch_string-1.0-1.rockspec"))
      end)
   
      it("LuaRocks lint mismatch version", function()
         write_file("type_mismatch_version-1.0-1.rockspec", [[
            package="type_mismatch_version"
            version="1.0"
         ]], finally)
         assert.is_false(run.luarocks_bool("lint type_mismatch_version-1.0-1.rockspec"))
      end)
   
      it("LuaRocks lint mismatch table", function()
         write_file("type_mismatch_table-1.0-1.rockspec", [[
            package="type_mismatch_table"
            version="1.0-1"

            source = "not a table"
         ]], finally)
         assert.is_false(run.luarocks_bool("lint type_mismatch_table-1.0-1.rockspec"))
      end)
   
      it("LuaRocks lint mismatch no build table", function()
         write_file("no_build_table-1.0-1.rockspec", [[
            package = "no_build_table"
            version = "0.1-1"
            source = {
               url = "http://example.com/foo/tar.gz"
            }
            description = {
               summary = "A rockspec with no build field",
            }
            dependencies = {
               "lua >= 5.1"
            }
         ]], finally)
         assert.is_false(run.luarocks_bool("lint no_build_table-1.0-1.rockspec"))
      end)
   end)
end)
