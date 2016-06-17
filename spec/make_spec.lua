local make = require("luarocks.make")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

expose("LuaRocks make tests #blackbox #b_make", function()
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
      testing_paths = test_env.testing_paths
   end)

   it("LuaRocks make with no flags/arguments", function()
   	lfs.chdir("new_test")
      assert.is_false(run.luarocks_bool("make"))
      lfs.chdir(testing_paths.luarocks_dir)
   end)
end)