local test_env = require("new_test/test_environment")
local site_config = require("luarocks.site_config")
local lfs = require("lfs")

expose("LuaRocks config tests #blackbox #b_config", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      testing_paths = test_env.testing_paths
      run = test_env.run
   end)

   it("LuaRocks config with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("config"))
   end)
   it("LuaRocks config include dir", function()
      local output = run.luarocks("config --lua-incdir")
      assert.are.same(output, site_config.LUA_INCDIR) --!not sure!
   end)
   it("LuaRocks config library dir", function()
      local output = run.luarocks("config --lua-libdir")
      assert.are.same(output, site_config.LUA_LIBDIR) --!not sure!
   end)
   it("LuaRocks config lua version", function()
      local output = run.luarocks("config --lua-ver")
      local lua_version = _VERSION:gsub("Lua ", "")
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