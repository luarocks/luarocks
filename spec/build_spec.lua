local build = require("luarocks.build")
local test_env = require("new_test/test_environment")

extra_rocks={
"/lpeg-0.12-1.src.rock"
}

expose("LuaRocks build tests #blackbox #b_build", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   it("LuaRocks build with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("build"))
   end)
   it("LuaRocks build invalid", function()
      assert.is_false(run.luarocks_bool("build invalid"))
   end)
   it("LuaRocks build fail build permissions", function()
      if test_env.TEST_TARGET_OS == "osx" or test_env.TEST_TARGET_OS == "linux" then
         assert.is_false(run.luarocks_bool("build --tree=/usr lpeg"))
      end
   end)
   it("LuaRocks build fail build permissions parent", function()
      if test_env.TEST_TARGET_OS == "osx" or test_env.TEST_TARGET_OS == "linux" then
         assert.is_false(run.luarocks_bool("build --tree=/usr/invalid lpeg"))
      end
   end)

   it("LuaRocks build lpeg verbose", function()
      assert.is_true(run.luarocks_bool("build --verbose lpeg"))
   end)
end)
