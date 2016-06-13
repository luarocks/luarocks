local install = require("luarocks.install")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

--TODO
describe("new test #whitebox #w_install", function()
   it("trivial_test", function()
      assert.are.same(1,1)
   end)
end)

--TODO
describe("LuaRocks install tests #blackbox #b_install", function()

   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)

   it("LuaRocks install with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("install", env_variables))
   end)
   it("LuaRocks install with invalid argument", function()
      assert.is_false(run.luarocks_bool("install invalid", env_variables))
   end)
   it('LuaRocks install luasec with skipping dependency checks', function()
      run.luarocks(" install luasec --nodeps", env_variables)
      assert.is_true(run.luarocks_bool("show luasec", env_variables))
      assert.is_false(run.luarocks_bool("show luasocket;", env_variables))

      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasocket"))
   end)
   it("LuaRocks install with local flag as root", function()
      local tmp_user = os.getenv("USER")
      env_variables.USER = "root"
      assert.is_false(run.luarocks_bool("install install --local luasocket", env_variables))
      env_variables.USER = tmp_user
   end)
end)