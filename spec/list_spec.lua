local test_env = require("test/test_environment")
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
      assert.is.truthy(output:find("luacov"))
   end)

   it("LuaRocks list porcelain", function()
      local output = run.luarocks("list --porcelain")
      local path = testing_paths.testing_sys_tree:gsub("-", "--") -- !not sure! why this is good
      assert.is.truthy(output:find("luacov\t0.11.0--1\tinstalled\t" .. path .. "/lib/luarocks/rocks" ))
   end)

   it("LuaRocks install outdated and list it", function()
      assert.is_true(run.luarocks_bool("install say 1.0-1"))
      local output = run.luarocks("list --outdated")
      assert.is.truthy(output:find("say"))
   end)
   
   it("LuaRocks list invalid tree", function()
      local output = run.luarocks("--tree=/some/invalid/tree list")
      assert.are.same(output, "Installed rocks:----------------")
   end)
end)
