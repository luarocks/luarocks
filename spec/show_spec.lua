local show = require("luarocks.show")
local test_env = require("new_test/test_environment")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

describe("LuaRocks show tests #blackbox #b_show", function()
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)

   it("LuaRocks show with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("show", env_variables))
   end)
   --TODO
   describe("LuaRocks show basic tests with flags", function()
      it("LuaRocks show invalid", function()
         assert.is_false(run.luarocks_bool("show invalid", env_variables))
      end)
      --TODO
      it("LuaRocks show luacov", function()
         local output = run.luarocks("show luacov", env_variables)
      end)
      it("LuaRocks show modules of luacov", function()
         local output = run.luarocks("show --modules luacov", env_variables)
      end)
      it("LuaRocks show dependencies of luacov", function()
         local output = run.luarocks("show --deps luacov", env_variables)
      end)
      it("LuaRocks show rockspec of luacov", function()
         local output = run.luarocks("show --rockspec luacov", env_variables)
      end)
      it("LuaRocks show mversion of luacov", function()
         local output = run.luarocks("show --mversion luacov", env_variables)
      end)
      it("LuaRocks show rock tree of luacov", function()
         local output = run.luarocks("show --rock-tree luacov", env_variables)
      end)
      it("LuaRocks show rock directory of luacov", function()
         local output = run.luarocks("show --rock-dir luacov", env_variables)
      end)
   end)

   it("LuaRocks show old version of luacov", function()
      run.luarocks("install luacov 0.11.0", env_variables)
      run.luarocks("show luacov 0.11.0", env_variables)
   end)
end)
