local install = require("luarocks.install")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")


extra_rocks={
"/luasec-0.6-1.rockspec",
"/luasocket-3.0rc1-1.src.rock",
"/luasocket-3.0rc1-1.rockspec"
}

--TODO
describe("new test #whitebox #w_install", function()
   it("trivial_test", function()
      assert.are.same(1,1)
   end)
end)

--TODO
expose("LuaRocks install tests #blackbox #b_install", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
      testing_paths = test_env.testing_paths
   end)

   it("LuaRocks install with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("install"))
   end)
   it("LuaRocks install with invalid argument", function()
      assert.is_false(run.luarocks_bool("install invalid"))
   end)
   it('LuaRocks install luasec with skipping dependency checks', function()
      run.luarocks(" install luasec --nodeps")
      assert.is_true(run.luarocks_bool("show luasec"))
      assert.is_false(run.luarocks_bool("show luasocket"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasocket"))
   end)
   it("LuaRocks install with local flag as root", function()
      assert.is_false(run.luarocks_bool("install --local luasocket", { USER = "root" } ))
   end)
end)