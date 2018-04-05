local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/validate-args-1.5.4-1.rockspec"
}

describe("LuaRocks download tests #blackbox #b_download", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("LuaRocks download with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("download"))
   end)

   it("LuaRocks download invalid", function()
      assert.is_false(run.luarocks_bool("download invalid"))
   end)

   it("LuaRocks download all with delete downloaded files", function() --TODO maybe download --all more rocks
      assert.is_true(run.luarocks_bool("download --all validate-args"))
      assert.is.truthy(lfs.attributes("validate-args-1.5.4-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "validate--args--")
   end)
   
   it("LuaRocks download rockspec version", function()
      assert.is_true(run.luarocks_bool("download --rockspec validate-args 1.5.4-1"))
      assert.is.truthy(lfs.attributes("validate-args-1.5.4-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "validate--args--")
   end)

   describe("#namespaces", function()
      it("retrieves namespaced rockspec", function()
         finally(function()
            os.remove("a_rock-2.0-1.rockspec")
         end)
         assert(run.luarocks_bool("download a_user/a_rock --rockspec --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(lfs.attributes("a_rock-2.0-1.rockspec"))
      end)

      it("retrieves namespaced rock", function()
         finally(function()
            os.remove("a_rock-2.0-1.src.rock")
         end)
         assert(run.luarocks_bool("download a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(lfs.attributes("a_rock-2.0-1.src.rock"))
      end)
   end)


end)
