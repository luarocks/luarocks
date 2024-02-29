local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables
local write_file = test_env.write_file
local get_tmp_path = test_env.get_tmp_path
local hardcoded

describe("LuaRocks config tests #integration", function()

   lazy_setup(function()
      test_env.setup_specs()
      -- needs to be required here, because hardcoded is created after first loading of specs
      hardcoded = require("luarocks.core.hardcoded")
   end)

   describe("full configuration query", function()
      it("no flags/arguments", function()
         assert.match("rocks_servers = {", run.luarocks("config"))
      end)

      it("--json", function()
         assert.match('"rocks_servers":[', run.luarocks("config --json"), 1, true)
      end)

      it("with --tree respects custom config", function()
         write_file("my_config.lua", [[
            rocks_trees = {
               {
                  name = "system",
                  root = "/example/tree",
                  lua_dir = "/example/luadir",
               },
            }
         ]], finally)
         local output = run.luarocks("config", {LUAROCKS_CONFIG = "my_config.lua"})
         assert.match([[deploy_lua_dir = "/example/luadir"]], output)
         output = run.luarocks("config --tree=system", {LUAROCKS_CONFIG = "my_config.lua"})
         assert.match([[deploy_lua_dir = "/example/luadir"]], output)
      end)

      it("#unix can find config via $XDG_CONFIG_HOME", function()
         local tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         lfs.mkdir(tmpdir .. "/luarocks")
         local tmp_config_file = tmpdir .. "/luarocks/config-" .. test_env.lua_version .. ".lua"
         write_file(tmp_config_file, [[
            rocks_trees = {
               {
                  name = "system",
                  root = "/example/tree",
                  lua_dir = "/example/luadir",
               },
            }
         ]])
         finally(function()
            os.remove(tmp_config_file)
            lfs.rmdir(tmpdir .. "/luarocks")
            lfs.rmdir(tmpdir)
         end)

         local output = run.luarocks("config --verbose", {XDG_CONFIG_HOME = tmpdir, LUAROCKS_CONFIG="invalid"})
         assert.match([[deploy_lua_dir = "/example/luadir"]], output)
      end)
   end)

   describe("query flags", function()
      it("--lua-incdir returns a subdir of LUA_DIR", function()
         local output = run.luarocks("config --lua-incdir")
         assert.match(hardcoded.LUA_DIR, output, 1, true)
      end)

      it("--lua-libdir returns a subdir of LUA_DIR", function()
         local output = run.luarocks("config --lua-libdir")
         assert.match(hardcoded.LUA_DIR, output, 1, true)
      end)

      it("--lua-ver returns the Lua version", function()
         local output = run.luarocks("config --lua-ver")
         local lua_version = _VERSION:gsub("Lua ", "")
         if test_env.LUAJIT_V then
            lua_version = "5.1"
         end
         assert.are.same(lua_version, output)
      end)

      it("--rock-trees lists rock trees", function()
         assert.is_true(run.luarocks_bool("config --rock-trees"))
      end)

      describe("--user-config", function()
         it("returns user config dir", function()
            local user_config_path = run.luarocks("config --user-config")
            assert.is.truthy(lfs.attributes(user_config_path))
         end)

         it("handles a missing user config", function()
            local output = run.luarocks("config --user-config", {LUAROCKS_CONFIG = "missing_file.lua"})
            assert.match("Warning", output)
         end)
      end)

      describe("--system-config", function()
         local scdir = testing_paths.testing_lrprefix .. "/etc/luarocks"
         local configfile = scdir .. "/config-" .. env_variables.LUA_VERSION .. ".lua"

         it("fails if system config doesn't exist", function()
            os.rename(configfile, configfile .. ".bak")
            finally(function()
               os.rename(configfile .. ".bak", configfile)
            end)
            assert.is_false(run.luarocks_bool("config --system-config"))
         end)

         it("fails if system config is invalid", function()
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

   describe("read config keys", function()
      it("reads a simple config key", function()
         local output = run.luarocks("config user_agent")
         assert.match("LuaRocks/", output)
      end)

      it("reads an array config key", function()
         local output = run.luarocks("config rocks_trees[2]")
         assert.match("{%s*name", output)
      end)

      it("can read as JSON", function()
         local output = run.luarocks("config rocks_trees --json")
         assert.match('^%[{', output)
      end)

      it("reads an array -> hash config key", function()
         local output = run.luarocks("config rocks_trees[2].name")
         assert.match("[a-z]+", output)
      end)

      it("reads a hash config key", function()
         local output = run.luarocks("config variables.ICACLS")
         assert.same("icacls", output)
      end)

      it("fails on invalid config key", function()
         local output = run.luarocks("config xyz")
         assert.match("Error: Unknown entry xyz", output)
      end)
   end)

   describe("unset config keys", function()
      it("unsets a simple config key", function()
         test_env.run_in_tmp(function(tmpdir)
            local myproject = tmpdir .. "/myproject"
            lfs.mkdir(myproject)
            lfs.chdir(myproject)

            assert(run.luarocks("init"))
            assert.truthy(run.luarocks_bool("config my_var my_value"))

            local output = run.luarocks("config my_var")
            assert.match("my_value", output)

            assert.truthy(run.luarocks_bool("config my_var --unset"))

            output = run.luarocks("config my_var")
            assert.not_match("my_value", output)
         end, finally)
      end)
   end)

   describe("write config keys", function()
      it("rejects invalid --scope", function()
         assert.is_false(run.luarocks_bool("config web_browser foo --scope=foo"))
      end)

      it("reads an array config key", function()
         local output = run.luarocks("config rocks_trees[2]")
         assert.match("{%s*name", output)
      end)

      it("writes a simple config key", function()
         test_env.run_in_tmp(function(tmpdir)
            local myproject = tmpdir .. "/myproject"
            lfs.mkdir(myproject)
            lfs.chdir(myproject)

            assert(run.luarocks("init"))
            assert.truthy(run.luarocks_bool("config web_browser foo --scope=project"))

            local output = run.luarocks("config web_browser")
            assert.match("foo", output)
         end, finally)
      end)

      it("writes a hash config key", function()
         test_env.run_in_tmp(function(tmpdir)
            local myproject = tmpdir .. "/myproject"
            lfs.mkdir(myproject)
            lfs.chdir(myproject)

            assert(run.luarocks("init"))
            assert.truthy(run.luarocks_bool("config variables.FOO_DIR /foo/bar --scope=project"))

            local output = run.luarocks("config variables.FOO_DIR")
            assert.match("/foo/bar", output)
         end, finally)
      end)

      it("writes a boolean config key", function()
         test_env.run_in_tmp(function(tmpdir)
            local myproject = tmpdir .. "/myproject"
            lfs.mkdir(myproject)
            lfs.chdir(myproject)

            assert(run.luarocks("init"))
            assert.truthy(run.luarocks_bool("config hooks_enabled true"))

            local output = run.luarocks("config hooks_enabled")
            assert.match("true", output)
         end, finally)
      end)

      it("writes an array config key", function()
         test_env.run_in_tmp(function(tmpdir)
            local myproject = tmpdir .. "/myproject"
            lfs.mkdir(myproject)
            lfs.chdir(myproject)

            assert(run.luarocks("init"))
            assert.truthy(run.luarocks_bool("config external_deps_patterns.lib[1] testtest --scope=project"))

            local output = run.luarocks("config external_deps_patterns.lib[1]")
            assert.match("testtest", output)
         end, finally)
      end)

   end)

end)
