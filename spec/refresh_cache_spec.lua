local test_env = require("test/test_environment")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks refresh_cache tests #blackbox #b_refresh_cache", function()

   before_each(function()
      test_env.setup_specs()
   end)

   describe("LuaRocks-admin refresh cache tests #ssh", function()
      it("LuaRocks-admin refresh cache", function()
         assert.is_true(run.luarocks_admin_bool("--server=testing refresh_cache"))
      end)
   end)
end)
