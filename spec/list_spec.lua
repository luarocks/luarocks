local test_env = require("spec.util.test_env")
local V = test_env.V
local run = test_env.run
local testing_paths = test_env.testing_paths

local extra_rocks = {
   "/say-1.0-1.src.rock",
   "/say-1.2-1.src.rock"
}

describe("luarocks list #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("with no flags/arguments", function()
      local output = run.luarocks("list")
      assert.match("luacov", output)
   end)

   it("shows version number", function()
      local output = run.luarocks("list")
      assert.is.truthy(output:find("luacov"))
      assert.matches(V"${LUACOV}", output, 1, true)
   end)

   it("LuaRocks install outdated and list it", function()
      assert.is_true(run.luarocks_bool("install say 1.0-1"))
      local output = run.luarocks("list --outdated")
      assert.is.truthy(output:find("say"))
      assert.matches("1.0-1 < ", output, 1, true)
   end)
end)
