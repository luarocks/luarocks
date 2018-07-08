local test_env = require("spec.util.test_env")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks make_manifest tests #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   describe("LuaRocks-admin make manifest tests", function()
      it("LuaRocks-admin make manifest", function()
         assert.is_true(run.luarocks_admin_bool("make_manifest"))
      end)
   end)
end)
