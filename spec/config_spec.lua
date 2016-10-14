local test_env = require("test/test_environment")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables
local site_config

test_env.unload_luarocks()

describe("LuaRocks config tests #blackbox #b_config", function()
   
   before_each(function()
      test_env.setup_specs()
      test_env.unload_luarocks() -- need to be required here, because site_config is created after first loading of specs
      site_config = require("luarocks.site_config")
   end)

   describe("LuaRocks config - basic tests", function()
      it("LuaRocks config with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("config"))
      end)
      
      it("LuaRocks config include dir", function()
         local output = run.luarocks("config --lua-incdir")
         if test_env.TEST_TARGET_OS == "windows" then
            assert.are.same(output, site_config.LUA_INCDIR:gsub("\\","/"))
         else
            assert.are.same(output, site_config.LUA_INCDIR)
         end
      end)
      
      it("LuaRocks config library dir", function()
         local output = run.luarocks("config --lua-libdir")
         if test_env.TEST_TARGET_OS == "windows" then
            assert.are.same(output, site_config.LUA_LIBDIR:gsub("\\","/"))
         else
            assert.are.same(output, site_config.LUA_LIBDIR)
         end
      end)
      
      it("LuaRocks config lua version", function()
         local output = run.luarocks("config --lua-ver")
         local lua_version = _VERSION:gsub("Lua ", "")
         if test_env.LUAJIT_V then
            lua_version = "5.1"
         end
         assert.are.same(output, lua_version)
      end)
      
      it("LuaRocks config rock trees", function()
         assert.is_true(run.luarocks_bool("config --rock-trees"))
      end)
      
      it("LuaRocks config user config", function()
         local user_config_path = run.luarocks("config --user-config")
         assert.is.truthy(lfs.attributes(user_config_path))
      end)
      
      it("LuaRocks config missing user config", function()
         assert.is_false(run.luarocks_bool("config --user-config", {LUAROCKS_CONFIG = "missing_file.lua"}))
      end)
   end)

   describe("LuaRocks config - more complex tests", function()
      local scdir = testing_paths.testing_lrprefix .. "/etc/luarocks"
      local versioned_scname = scdir .. "/config-" .. env_variables.LUA_VERSION .. ".lua"
      local scname = scdir .. "/config.lua"

      local configfile
      if test_env.TEST_TARGET_OS == "windows" then
         configfile = versioned_scname
      else
         configfile = scname
      end

      it("LuaRocks fail system config", function()
         os.rename(configfile, configfile .. ".bak")
         assert.is_false(run.luarocks_bool("config --system-config"))
         os.rename(configfile .. ".bak", configfile)
      end)
      
      it("LuaRocks system config", function()
         lfs.mkdir(testing_paths.testing_lrprefix)
         lfs.mkdir(testing_paths.testing_lrprefix .. "/etc/")
         lfs.mkdir(scdir)

         if test_env.TEST_TARGET_OS == "windows" then
            local output = run.luarocks("config --system-config")
            assert.are.same(output, configfile)
         else
            local sysconfig = io.open(configfile, "w+")
            sysconfig:write(" ")
            sysconfig:close()
            
            local output = run.luarocks("config --system-config")
            assert.are.same(output, configfile)
            os.remove(configfile)
         end
      end)
      
      it("LuaRocks fail system config invalid", function()
         lfs.mkdir(testing_paths.testing_lrprefix)
         lfs.mkdir(testing_paths.testing_lrprefix .. "/etc/")
         lfs.mkdir(scdir)

         if test_env.TEST_TARGET_OS == "windows" then
            test_env.copy(configfile, "configfile_temp")
            local sysconfig = io.open(configfile, "w+")
            sysconfig:write("if if if")
            sysconfig:close()
            assert.is_false(run.luarocks_bool("config --system-config"))
            test_env.copy("configfile_temp", configfile)
         else
            local sysconfig = io.open(configfile, "w+")
            sysconfig:write("if if if")
            sysconfig:close()
            assert.is_false(run.luarocks_bool("config --system-config"))
            os.remove(configfile)
         end
      end)
   end)
end)
