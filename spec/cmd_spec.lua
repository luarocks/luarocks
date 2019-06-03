local test_env = require("spec.util.test_env")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks command line #integration", function()
   
   setup(function()
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

end)
