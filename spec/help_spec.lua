local help = require("luarocks.help")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

describe("LuaRocks help tests #blackbox #b_help", function()   
   it("LuaRocks help with no flags/arguments", function()
      assert.is_true(run.luarocks_bool("help", env_variables))
   end)
   it("LuaRocks help invalid argument", function()
      assert.is_false(run.luarocks_bool("help invalid", env_variables))
   end)
   it("LuaRocks help config", function()
      assert.is_true(run.luarocks_bool("help config", env_variables))
   end)
   it("LuaRocks-admin help with no flags/arguments", function()
      assert.is_true(run.luarocks_admin_bool("help", env_variables))
   end)
end)


