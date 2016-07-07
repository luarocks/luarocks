local test_env = require("test/test_environment")
local lfs = require("lfs")

test_env.unload_luarocks()
local refresh_cache = require("luarocks.refresh_cache")

expose("LuaRocks refresh_cache tests #blackbox #b_refresh_cache", function()
	
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   describe("LuaRocks-admin refresh cache tests #ssh", function()
      it("LuaRocks-admin refresh cache", function()
         assert.is_true(run.luarocks_admin_bool("--server=testing refresh_cache"))
      end)
   end)
end)