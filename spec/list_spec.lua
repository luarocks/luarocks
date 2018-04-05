local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/say-1.0-1.src.rock",
   "/say-1.2-1.src.rock"
}

describe("LuaRocks list tests #blackbox #b_list", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("LuaRocks list with no flags/arguments", function()
      local output = run.luarocks("list")
      assert.match("luacov", output)
   end)

   it("LuaRocks list porcelain", function()
      local output = run.luarocks("list --porcelain")
      assert.is.truthy(output:find("luacov\t0.11.0-1\tinstalled\t" .. testing_paths.testing_sys_rocks, 1, true))
   end)

   it("LuaRocks install outdated and list it", function()
      assert.is_true(run.luarocks_bool("install say 1.0-1"))
      local output = run.luarocks("list --outdated")
      assert.is.truthy(output:find("say"))
   end)
   
   it("LuaRocks list invalid tree", function()
      local output = run.luarocks("--tree=/some/invalid/tree list")
      assert(output:find("Installed rocks for Lua "..test_env.lua_version, 1, true))
   end)
end)
