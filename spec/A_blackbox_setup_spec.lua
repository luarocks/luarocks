local test_env = require("new_test/test_environment")
local lfs = require("lfs")

_G.test_setup = {}
local tmp = _G.test_setup
local arg = arg or { ... }

expose("Setup functions required for white box testing #blackbox #setup", function()
   it("Setting up...", function()
      --Set required arguments for testing
      test_env.set_args()
      -- Download required rocks and rockspecs for testing
      local rocks = {}
      rocks[#rocks+1] = "/luacov-0.11.0-1.rockspec"
      rocks[#rocks+1] = "/luacov-0.11.0-1.src.rock"

      if test_env.TYPE_TEST_ENV == "full" then 
         rocks[#rocks+1] = "/luafilesystem-1.6.3-1.src.rock"
         rocks[#rocks+1] = "/luasocket-3.0rc1-1.src.rock"
         rocks[#rocks+1] = "/luasocket-3.0rc1-1.rockspec"
         rocks[#rocks+1] = "/luaposix-33.2.1-1.src.rock"
         rocks[#rocks+1] = "/md5-1.2-1.src.rock"
         rocks[#rocks+1] = "/lzlib-0.4.1.53-1.src.rock"
      end
      if test_env.TYPE_TEST_ENV == "full" and test_env.LUA_V ~= "5.1.5" then
         rocks[#rocks+1] = "/luabitop-1.0.2-1.rockspec"
         rocks[#rocks+1] = "/luabitop-1.0.2-1.src.rock"
      end
      
      for i=1, #arg do
         if arg[i] == "-t" or arg[i] == "--tags" then
            if arg[i+1]:find("install") then
               rocks[#rocks+1] = "/luasec-0.6-1.rockspec"
               rocks[#rocks+1] = "/luasocket-3.0rc1-1.src.rock"
               rocks[#rocks+1] = "/luasocket-3.0rc1-1.rockspec"
            end
            if arg[i+1]:find("search") then
               rocks[#rocks+1] = "/lzlib-0.4.1.53-1.src.rock"
            end
            if arg[i+1]:find("build") then
               rocks[#rocks+1] = "/lpeg-0.12-1.src.rock"
            end
            if arg[i+1]:find("download") then
               rocks[#rocks+1] = "/validate-args-1.5.4-1.rockspec"
            end
            if arg[i+1]:find("list") then
               rocks[#rocks+1] = "/say-1.2-1.src.rock"
               rocks[#rocks+1] = "/say-1.0-1.src.rock"
            end
         end
      end

      -- Build testing environment
      test_env.main(rocks)
      lfs.chdir("new_test")

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
