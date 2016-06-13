local test_env = require("new_test/test_environment")
local site_config = require("luarocks.site_config")
local lfs = require("lfs")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

--TODO
describe("LuaRocks config tests #blackbox #b_config", function()
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)

   it("LuaRocks config with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("config", env_variables))
   end)
   it("LuaRocks config include dir", function()
      local output = run.luarocks("config --lua-incdir", env_variables)
      assert.are.same(output, site_config.LUA_INCDIR) --!not sure!
   end)
   it("LuaRocks config library dir", function()
      local output = run.luarocks("config --lua-libdir", env_variables)
      assert.are.same(output, site_config.LUA_LIBDIR) --!not sure!
   end)
   it("LuaRocks config lua version", function()
      local output = run.luarocks("config --lua-ver", env_variables)
      local lua_version = _VERSION:gsub("Lua ", "")
      assert.are.same(output, lua_version)
   end)
   it("LuaRocks config rock trees", function()
      assert.is_true(run.luarocks_bool("config --rock-trees", env_variables))
   end)
   it("LuaRocks config user config", function()
      local user_config_path = run.luarocks("config --user-config", env_variables)
      assert.is.truthy(lfs.attributes(user_config_path))
   end)
   it("LuaRocks config missing user config", function()
      local tmp_env = env_variables.LUAROCKS_CONFIG
      env_variables.LUAROCKS_CONFIG = "missing_file.lua"
      assert.is_false(run.luarocks_bool("config --user-config", env_variables))
      env_variables.LUAROCKS_CONFIG = tmp_env
   end)
end)