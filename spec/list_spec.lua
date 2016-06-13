local list = require("luarocks.list")
local test_env = require("new_test/test_environment")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

describe("LuaRocks list tests #blackbox #b_list", function()
   
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)
   
   it("LuaRocks list with no flags/arguments", function()
      local output = run.luarocks("list", env_variables)
      assert.is.truthy(output:find("luacov"))
   end)
   it("LuaRocks list porcelain", function()
      local output = run.luarocks("list --porcelain", env_variables)

      local path = testing_paths.testing_sys_tree:gsub("-", "--") -- !not sure! why this is good
      assert.is.truthy(output:find("luacov\t0.11.0--1\tinstalled\t" .. path .. "/lib/luarocks/rocks" ))
   end)
   it("LuaRocks install outdated and list it", function()
      assert.is_true(run.luarocks_bool("install say 1.0-1", env_variables))
      local output = run.luarocks("list --outdated", env_variables)
      assert.is.truthy(output:find("say"))
   end)
   --TODOOOO
   it("LuaRocks list invalid tree", function()
      -- assert.is_false(
      local output = run.luarocks("--tree=/some/invalid/tree list", env_variables)
      print(output)
   end)
   -- !move this to pack!
   -- it("LuaRocks list invalid tree", function()
   --    -- luarocks list && $luarocks pack luacov && rm ./luacov-*.rock;
   --    run.luarocks("list", env_variables)
   --    run.luarocks("pack luacov", env_variables)
   --    -- os.remove("luacov-*.rock")
   -- end)
end)
