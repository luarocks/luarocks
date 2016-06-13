local path = require("luarocks.path")
local test_env = require("new_test/test_environment")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

--TODO
describe("LuaRocks path tests #blackbox #b_path", function()
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)

   it("LuaRocks path bin", function()
      assert.is_true(run.luarocks_bool("path --bin", env_variables))
   end)
   it("LuaRocks path lr-path", function()
      assert.is_true(run.luarocks_bool("path --lr-path", env_variables))
   end)
   it("LuaRocks path lr-cpath", function()
      assert.is_true(run.luarocks_bool("path --lr-cpath", env_variables))
   end)
   it("LuaRocks path with tree", function()
      assert.is_true(run.luarocks_bool("path --tree=lua_modules", env_variables))
   end)

end)
