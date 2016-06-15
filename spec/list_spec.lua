local list = require("luarocks.list")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

extra_rocks={
"/say-1.0-1.src.rock",
"/say-1.2-1.src.rock"
}

describe("new test #whitebox #w_list", function()
   it("trivial_test", function()
      assert.are.same(1,1)
   end)
end)

expose("LuaRocks list tests #blackbox #b_list", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
      testing_paths = test_env.testing_paths
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
   --TODOOOO
   it("LuaRocks list invalid tree", function()
      -- assert.is_false(
      -- local output = run.luarocks("--tree=/some/invalid/tree list")
      -- print(output)
   end)
   -- !move this to pack!
   -- it("LuaRocks list invalid tree", function()
   --    -- luarocks list && $luarocks pack luacov && rm ./luacov-*.rock;
   --    run.luarocks("list", env_variables)
   --    run.luarocks("pack luacov", env_variables)
   --    -- os.remove("luacov-*.rock")
   -- end)
end)
