local install = require("luarocks.install")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")


extra_rocks={
   "/cprint-0.1-2.src.rock",
   "/cprint-0.1-2.rockspec",
   "/lpeg-0.12-1.src.rock",
   "/luasec-0.6-1.rockspec",
   "/luasocket-3.0rc1-1.src.rock",
   "/luasocket-3.0rc1-1.rockspec",
   "/lxsh-0.8.6-2.src.rock",
   "/lxsh-0.8.6-2.rockspec",
   "/wsapi-1.6-1.src.rock"
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
      testing_paths = test_env.testing_paths
      run = test_env.run
      platform = test_env.platform
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

   it("LuaRocks install luasec and show luasocket (dependency)", function()
      assert.is_true(run.luarocks_bool("install luasec"))
      assert.is_true(run.luarocks_bool("show luasocket"))
   end)
   it("LuaRocks install wsapi with bin", function()
      run.luarocks_bool("install wsapi")
   end)
   it("LuaRocks install only-deps of lxsh show there is no lxsh", function()
      assert.is_true(run.luarocks_bool("install lxsh 0.8.6-2 --only-deps"))
      assert.is_false(run.luarocks_bool("show lxsh"))
   end)
   it("LuaRocks install invalid rock", function()
      assert.is_false(run.luarocks_bool("install \"invalid.rock\" "))
   end)
   it("LuaRocks install not a zip file", function()
      assert.is_false(run.luarocks_bool("install " .. testing_paths.testing_dir .. "/testfiles/not_a_zipfile-1.0-1.src.rock"))
   end)
   it("LuaRocks install incompatible architecture", function()
      assert.is_false(run.luarocks_bool("install \"foo-1.0-1.impossible-x86.rock\" "))
   end)
   it("LuaRocks install only-deps of luasocket packed rock", function()
      test_env.need_luasocket()
      local output = run.luarocks("install --only-deps " .. testing_paths.testing_cache .. "/luasocket-3.0rc1-1." .. platform .. ".rock")
      assert.are.same(output, "Successfully installed dependencies for luasocket 3.0rc1-1")
   end)

   it("LuaRocks install binary rock of cprint", function()
      assert.is_true(test_env.need_luasocket())
      assert.is_true(run.luarocks_bool("build --pack-binary-rock cprint"))
      assert.is_true(run.luarocks_bool("install cprint-0.1-2." .. platform .. ".rock"))
      assert.is_true(os.remove("cprint-0.1-2." .. platform .. ".rock"))
   end)
   
   it("LuaRocks install invalid patch", function() --need luasocket?
      assert.is_false(run.luarocks_bool("install " .. testing_paths.testing_dir .. "/testfiles/invalid_patch-0.1-1.rockspec"))
   end)

   it("LuaRocks install reinstall", function()
      assert.is_true(test_env.need_luasocket())
      assert.is_true(run.luarocks_bool("install " .. testing_paths.testing_cache .. "/luasocket-3.0rc1-1." .. platform .. ".rock"))
      assert.is_true(run.luarocks_bool("install --deps-mode=none " .. testing_paths.testing_cache .. "/luasocket-3.0rc1-1." .. platform .. ".rock"))
   end)

end)