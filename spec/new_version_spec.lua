local test_env = require("test/test_environment")
local lfs = require("lfs")

test_env.unload_luarocks()

local extra_rocks = {
   "/abelhas-1.0-1.rockspec"
}

describe("LuaRocks new_version tests #blackbox #b_new_version", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
      testing_paths = test_env.testing_paths
      run = test_env.run
   end)
   
   describe("LuaRocks new_version basic tests", function()
      it("LuaRocks new version with no flags/arguments", function()
         lfs.chdir("test")
         assert.is_false(run.luarocks_bool("new_version"))
         lfs.chdir(testing_paths.luarocks_dir)
      end)
      
      it("LuaRocks new version invalid", function()
         assert.is_false(run.luarocks_bool("new_version invalid"))
      end)
   end)

   describe("LuaRocks new_version more complex tests", function()
      it("LuaRocks new_version of luacov", function()
         assert.is_true(run.luarocks_bool("download --rockspec luacov 0.11.0"))
         assert.is_true(run.luarocks_bool("new_version luacov-0.11.0-1.rockspec 0.2"))
         assert.is.truthy(lfs.attributes("luacov-0.2-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "luacov--")
      end)

      it("LuaRocks new_version url of abelhas", function()
         assert.is_true(run.luarocks_bool("download --rockspec abelhas 1.0"))
         assert.is_true(run.luarocks_bool("new_version abelhas-1.0-1.rockspec 1.1 http://luaforge.net/frs/download.php/2658/abelhas-1.0.tar.gz"))
         assert.is.truthy(lfs.attributes("abelhas-1.1-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "abelhas--")
      end)
      
      it("LuaRocks new_version of luacov with tag", function()
         assert.is_true(run.luarocks_bool("download --rockspec luacov 0.11.0"))
         assert.is_true(run.luarocks_bool("new_version luacov-0.11.0-1.rockspec --tag v0.3"))
         assert.is.truthy(lfs.attributes("luacov-0.3-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "luacov--")
      end)
   end)
end)
