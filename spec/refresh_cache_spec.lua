local test_env = require("spec.util.test_env")
local run = test_env.run

describe("luarocks-admin refresh_cache #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   it("runs #ssh", function()
      assert.is_true(run.luarocks_admin_bool("--server=testing refresh_cache"))
   end)
end)
