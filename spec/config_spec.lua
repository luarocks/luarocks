local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables
local hardcoded

test_env.unload_luarocks()

describe("LuaRocks config tests #integration", function()
   
   before_each(function()
      test_env.setup_specs()
      test_env.unload_luarocks() -- need to be required here, because hardcoded is created after first loading of specs
      hardcoded = require("luarocks.core.hardcoded")
   end)

   describe("LuaRocks config - basic tests", function()
      it("LuaRocks config with no flags/arguments", function()
         assert.match("rocks_servers", run.luarocks("config"))
      end)
      
      it("LuaRocks config include dir returns a subdir of LUA_DIR", function()
         local output = run.luarocks("config --lua-incdir")
         assert.match(hardcoded.LUA_DIR, output, 1, true)
      end)
      
      it("LuaRocks config library dir returns a subdir of LUA_DIR", function()
         local output = run.luarocks("config --lua-libdir")
         assert.match(hardcoded.LUA_DIR, output, 1, true)
      end)
      
      it("LuaRocks config lua version", function()
         local output = run.luarocks("config --lua-ver")
         local lua_version = _VERSION:gsub("Lua ", "")
         if test_env.LUAJIT_V then
            lua_version = "5.1"
         end
         assert.are.same(lua_version, output)
      end)
      
      it("LuaRocks config rock trees", function()
         assert.is_true(run.luarocks_bool("config --rock-trees"))
      end)
      
      it("LuaRocks config user config", function()
         local user_config_path = run.luarocks("config --user-config")
         assert.is.truthy(lfs.attributes(user_config_path))
      end)
      
      it("LuaRocks config missing user config", function()
         local output = run.luarocks("config --user-config", {LUAROCKS_CONFIG = "missing_file.lua"})
         assert.truthy(output:match("Warning"))
      end)
   end)

   describe("LuaRocks config - more complex tests", function()
      local scdir = testing_paths.testing_lrprefix .. "/etc/luarocks"
      local configfile = scdir .. "/config-" .. env_variables.LUA_VERSION .. ".lua"

      it("LuaRocks fail system config", function()
         os.rename(configfile, configfile .. ".bak")
         finally(function()
            os.rename(configfile .. ".bak", configfile)
         end)
         assert.is_false(run.luarocks_bool("config --system-config"))
      end)
      
      it("LuaRocks system config", function()
         lfs.mkdir(testing_paths.testing_lrprefix)
         lfs.mkdir(testing_paths.testing_lrprefix .. "/etc/")
         lfs.mkdir(scdir)

         local sysconfig = io.open(configfile, "w+")
         sysconfig:write(" ")
         sysconfig:close()
         finally(function()
            os.remove(configfile)
         end)
         
         local output = run.luarocks("config --system-config")
         assert.are.same(configfile, output)
      end)
      
      it("LuaRocks fail system config invalid", function()
         lfs.mkdir(testing_paths.testing_lrprefix)
         lfs.mkdir(testing_paths.testing_lrprefix .. "/etc/")
         lfs.mkdir(scdir)

         local sysconfig = io.open(configfile, "w+")
         sysconfig:write("if if if")
         sysconfig:close()
         finally(function()
            os.remove(configfile)
         end)
         assert.is_false(run.luarocks_bool("config --system-config"))
      end)
   end)
end)
