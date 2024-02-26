local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

local extra_rocks = {
   "/say-1.3-1.rockspec",
}

describe("luarocks download #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("download"))
   end)

   it("invalid", function()
      assert.is_false(run.luarocks_bool("download invalid"))
   end)

   it("all with delete downloaded files", function() --TODO maybe download --all more rocks
      assert.is_true(run.luarocks_bool("download --all say"))
      assert.is.truthy(lfs.attributes("say-1.3-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "say--")
   end)

   it("rockspec version", function()
      assert.is_true(run.luarocks_bool("download --rockspec say 1.3-1"))
      assert.is.truthy(lfs.attributes("say-1.3-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "say--")
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
