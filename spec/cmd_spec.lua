local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run

describe("LuaRocks command line #integration", function()

   lazy_setup(function()
      test_env.setup_specs()
   end)

   describe("--version", function()
      it("returns the LuaRocks version", function()
         local output = run.luarocks("--version")
         assert.match("LuaRocks main command-line interface", output, 1, true)
      end)

      it("runs if Lua detection fails", function()
         test_env.run_in_tmp(function(tmpdir)
            test_env.write_file("bad_config.lua", [[
               variables = {
                  LUA_DIR = "/bad/lua/dir",
               }
            ]], finally)
            local env = {
               LUAROCKS_CONFIG = "bad_config.lua"
            }
            local output = run.luarocks("--version", env)
            assert.match("LuaRocks main command-line interface", output, 1, true)
         end, finally)
      end)
   end)

   describe("--lua-dir", function()
      it("fails if given an invalid path", function()
         local output = run.luarocks("--lua-dir=/bad/lua/path")
         assert.match("Lua interpreter not found at /bad/lua/path", output, 1, true)
      end)

      it("fails if given a valid path without Lua", function()
         local output = run.luarocks("--lua-dir=.")
         assert.match("Lua interpreter not found at .", output, 1, true)
      end)

      it("passes if given a valid path with Lua", function()
         assert.truthy(run.luarocks("--lua-dir=" .. test_env.testing_paths.luadir))
      end)

      it("passes if given a quoted path with Lua", function()
         assert.truthy(run.luarocks("--lua-dir '" .. test_env.testing_paths.luadir .. "'"))
      end)
   end)

   describe("--lua-version", function()
      it("fails if given something that is not a number", function()
         local output = run.luarocks("--lua-version=bozo")
         assert.match("malformed", output, 1, true)
      end)

      it("sets the version independently of project tree", function()
         test_env.run_in_tmp(function(tmpdir)
            assert.truthy(run.luarocks_bool("init --lua-version=" .. test_env.lua_version .. " --lua-versions=" .. test_env.lua_version))

            local output = run.luarocks("--lua-version=1.0")
            assert.match("Version%s*:%s*1.0", output)

            output = run.luarocks("--lua-version=1.0 --project-tree=.")
            assert.match("Version%s*:%s*1.0", output)
         end, finally)
      end)
   end)

   it("detects version based on project tree", function()
      test_env.run_in_tmp(function(tmpdir)
         assert.truthy(run.luarocks_bool("init --lua-version=" .. test_env.lua_version))
         assert.truthy(run.luarocks_bool("config lua_version 1.0 --project-tree=" .. tmpdir .. "/lua_modules"))

         lfs.mkdir("aaa")
         lfs.chdir("aaa")
         lfs.mkdir("bbb")
         lfs.chdir("bbb")

         local output = run.luarocks("")
         assert.match("Version%s*:%s*1.0", output)
      end, finally)
   end)

   -- for backward compatibility
   it("detects version of a project based on config", function()
      test_env.run_in_tmp(function(tmpdir)
         assert.truthy(run.luarocks_bool("init --lua-version=" .. test_env.lua_version))
         os.remove(".luarocks/config-" .. test_env.lua_version .. ".lua")
         os.remove(".luarocks/default-lua-version.lua")
         test_env.write_file(".luarocks/config-5.2.lua", [[ ]], finally)

         lfs.mkdir("aaa")
         lfs.chdir("aaa")
         lfs.mkdir("bbb")
         lfs.chdir("bbb")

         local output = run.luarocks("")
         assert.match("Version%s*:%s*5.2", output)
      end, finally)
   end)

end)
