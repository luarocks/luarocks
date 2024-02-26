local test_env = require("spec.util.test_env")
local run = test_env.run

describe("luarocks help #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   it("with no flags/arguments", function()
      assert.is_true(run.luarocks_bool("help"))
   end)

   it("invalid argument", function()
      assert.is_false(run.luarocks_bool("help invalid"))
   end)

   it("config", function()
      assert.is_true(run.luarocks_bool("help config"))
   end)

   it("luarocks-admin help with no flags/arguments", function()
      assert.is_true(run.luarocks_admin_bool(test_env.quiet("help")))
   end)
end)
