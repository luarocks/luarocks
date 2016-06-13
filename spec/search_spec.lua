local search = require("luarocks.search")
local test_env = require("new_test/test_environment")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

--TODO
describe("LuaRocks search tests #blackbox #b_search", function()
   it("LuaRocks search with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("search", env_variables))
   end)
   it("LuaRocks search zlib", function()
      assert.is_true(run.luarocks_bool("search zlib", env_variables))
   end)
   it("LuaRocks search zlib 1.1", function()
      assert.is_true(run.luarocks_bool("search zlib 1.1", env_variables))
   end)
   it("LuaRocks search missing rock", function()
      assert.is_true(run.luarocks_bool("search missing_rock", env_variables))
   end)
   it("LuaRocks search with flag all", function()
      assert.is_true(run.luarocks_bool("search --all", env_variables))
   end)
   it("LuaRocks search zlib", function()
      local num = 123
      assert.is_true(run.luarocks_bool("search " .. num, env_variables))
   end)
end)