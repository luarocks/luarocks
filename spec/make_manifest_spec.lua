local test_env = require("test/test_environment")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks make_manifest tests #blackbox #b_make_manifest", function()

   before_each(function()
      test_env.setup_specs()
   end)

   describe("LuaRocks-admin make manifest tests", function()
      it("LuaRocks-admin make manifest", function()
         assert.is_true(run.luarocks_admin_bool("make_manifest"))
      end)
   end)
end)
