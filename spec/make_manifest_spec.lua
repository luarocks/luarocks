local test_env = require("spec.util.test_env")
local run = test_env.run

test_env.unload_luarocks()

describe("luarocks make_manifest #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   it("runs", function()
      assert.is_true(run.luarocks_admin_bool("make_manifest"))
   end)
end)
