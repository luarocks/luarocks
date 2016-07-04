local test_env = require("new_test/test_environment")
local lfs = require("lfs")

test_env.unload_luarocks()
local cfg = require("luarocks.cfg")

expose("LuaRocks config tests #blackbox #b_config", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      test_env.unload_luarocks() -- need to be required here, because site_config is created after first loading of specs
      site_config = require("luarocks.site_config")
      testing_paths = test_env.testing_paths
      run = test_env.run
   end)

   describe("LuaRocks config - basic tests", function()
      it("LuaRocks config with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("config"))
      end)
      
      it("LuaRocks config include dir", function()
         local output = run.luarocks("config --lua-incdir")
         assert.are.same(output, site_config.LUA_INCDIR)
      end)
      
      it("LuaRocks config library dir", function()
         local output = run.luarocks("config --lua-libdir")
         assert.are.same(output, site_config.LUA_LIBDIR)
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
      it("LuaRocks fail system config", function()
         os.remove(testing_paths.testing_lrprefix .. "/etc/luarocks/config.lua")
         assert.is_false(run.luarocks_bool("config --system-config;"))
      end)
      
      it("LuaRocks system config", function()
         local scdir = testing_paths.testing_lrprefix .. "/etc/luarocks"
         lfs.mkdir(testing_paths.testing_lrprefix)
         lfs.mkdir(testing_paths.testing_lrprefix .. "/etc/")
         lfs.mkdir(scdir)

         local sysconfig = io.open(scdir .. "/config.lua", "w+")
         sysconfig:write(" ")
         sysconfig:close()

         local output = run.luarocks("config --system-config;")
         assert.are.same(output, scdir .. "/config.lua")
         test_env.remove_dir(testing_paths.testing_lrprefix)
      end)
      
      it("LuaRocks fail system config invalid", function()
         local scdir = testing_paths.testing_lrprefix .. "/etc/luarocks"
         lfs.mkdir(testing_paths.testing_lrprefix)
         lfs.mkdir(testing_paths.testing_lrprefix .. "/etc/")
         lfs.mkdir(scdir)

         local sysconfig = io.open(scdir .. "/config.lua", "w+")
         sysconfig:write("if if if")
         sysconfig:close()

         assert.is_false(run.luarocks_bool("config --system-config;"))
         test_env.remove_dir(testing_paths.testing_lrprefix)
      end)
   end)
end)