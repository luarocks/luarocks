local install = require("luarocks.install")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

--TODO
describe("LuaRocks #whitebox_install", function()
   it("trivial_test", function()
      assert.are.same(1,1)
   end)
end)

--TODO
describe("Luarocks #blackbox_install", function()
      test_env.set_args()

      local testing_paths = test_env.set_paths(test_env.LUA_V)
      local env_variables = test_env.create_env(testing_paths)
      local md5sums = test_env.create_md5sums(testing_paths)
      local run = test_env.run_luarocks(testing_paths, env_variables) 
   
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)
   
   it("luarocks install with no arguments", function()
      local output = run.luarocks_bool(" install", env_variables)
      assert.is_false(output)
   end)
   it("luarocks install with invalid argument", function()
      local output = run.luarocks_bool(" install invalid", env_variables)
      assert.is_false(output)
   end)
   --  it('luarocks install luasec with skipping dependency checks', function()
   --    test_utils.luarocks_noprint(" install luasec --nodeps; ", test_utils.testing_env_variables)
   --    assert.is.truthy(lfs.attributes(test_utils.testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasec"))
   --    assert.is.falsy(lfs.attributes(test_utils.testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasocket"))
   -- end)
end)