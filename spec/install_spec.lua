local install = require("luarocks.install")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

local rocks = {"/luacov-coveralls-0.1.1-1.src.rock",
   "/luasec-0.6-1.rockspec",
   "/luacov-0.11.0-1.rockspec",
   "/luacov-0.11.0-1.src.rock",
   "/luasocket-3.0rc1-1.src.rock",
   "/luasocket-3.0rc1-1.rockspec",
   "/luafilesystem-1.6.3-1.src.rock",
   "/luabitop-1.0.2-1.rockspec",
   "/luabitop-1.0.2-1.src.rock"}

test_env.set_params()

local testing_paths = test_env.set_paths(test_env.LUA_V)
test_env.download_rocks(rocks, testing_paths.testing_server)

local env_variables = test_env.create_env(testing_paths)
local md5sums = test_env.create_md5sums(testing_paths)
local run = test_env.run_luarocks(testing_paths, env_variables) 

--TODO
describe("LuaRocks #install_whitebox", function()
   describe("basic test #install_whitebox_new", function()
      it("trivial_test2", function()
         assert.are.same(1,1)
      end)
   end)

   describe( "basic test #install_whitebox_old", function()
      it("trivial_test2", function()
         assert.are.same(1,1)
      end)
   end)
end)

--TODO
describe("Luarocks #install_blackbox", function()
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)
   
   it("luarocks install with no arguments", function()
      local output = run.luarocks(" install", env_variables)

   end)
   it("luarocks install with invalid argument", function()
      local output = run.luarocks(" install invalid", env_variables)
      
   end)
   --  it('luarocks install luasec with skipping dependency checks', function()
   --    test_utils.luarocks_noprint(" install luasec --nodeps; ", test_utils.testing_env_variables)
   --    assert.is.truthy(lfs.attributes(test_utils.testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasec"))
   --    assert.is.falsy(lfs.attributes(test_utils.testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasocket"))
   -- end)
end)