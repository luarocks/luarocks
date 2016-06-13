local test_env = require("new_test/test_environment")
local lfs = require("lfs")

_G.test_setup = {}
local tmp = _G.test_setup
local arg = arg or { ... }



expose("Setup functions required for white box testing #blackbox #setup", function()
   it("Setting up...", function()
      --TODO
      local rocks = {}
      for i=1, #arg do
         print(arg[i])
         if arg[i] == "-t" or arg[i] == "--tags" then
            if arg[i+1]:find("install") then
               --download these rocks
            end
            if arg[i+1]:find("make") then
               --download these rocks
            end
         end
      end

      rocks = {"/luacov-coveralls-0.1.1-1.src.rock",
         "/luasec-0.6-1.rockspec",
         "/luacov-0.11.0-1.rockspec",
         "/luacov-0.11.0-1.src.rock",
         "/luasocket-3.0rc1-1.src.rock",
         "/luasocket-3.0rc1-1.rockspec",
         "/luafilesystem-1.6.3-1.src.rock",
         "/luabitop-1.0.2-1.rockspec",
         "/luabitop-1.0.2-1.src.rock",
         "/luadoc-3.0.1-1.src.rock",
         "/lualogging-1.3.0-1.src.rock",
         "/stdlib-41.0.0-1.src.rock",
         "/say-1.2-1.src.rock",
         "/say-1.0-1.src.rock",
         "/lpeg-0.12-1.src.rock",
         "/validate-args-1.5.4-1.rockspec",
         "/lzlib-0.4.1.53-1.src.rock",
      }

      test_env.main(rocks)
      lfs.chdir("new_test")
      
      test_env.set_args()
      tmp.testing_paths = test_env.set_paths(test_env.LUA_V)
      tmp.env_variables = test_env.create_env(tmp.testing_paths)
      tmp.md5sums = test_env.create_md5sums(tmp.testing_paths)
      tmp.run = test_env.run_luarocks(tmp.testing_paths, tmp.env_variables)

      assert.is.truthy(tmp.testing_paths)
      assert.is.truthy(tmp.env_variables)
      assert.is.truthy(tmp.md5sums)
      assert.is.truthy(tmp.run)
   end)
end)
