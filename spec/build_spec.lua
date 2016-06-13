local build = require("luarocks.build")
local test_env = require("new_test/test_environment")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

describe("LuaRocks build tests #blackbox #b_build", function()
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)

   it("LuaRocks build with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("build", env_variables))
   end)
   it("LuaRocks build invalid", function()
      assert.is_false(run.luarocks_bool("build invalid", env_variables))
   end)
   it("LuaRocks build fail build permissions", function()
      if test_env.TEST_TARGET_OS == "osx" or test_env.TEST_TARGET_OS == "linux" then
         assert.is_false(run.luarocks_bool("build --tree=/usr lpeg", env_variables))
      end
   end)
   it("LuaRocks build fail build permissions parent", function()
      if test_env.TEST_TARGET_OS == "osx" or test_env.TEST_TARGET_OS == "linux" then
         assert.is_false(run.luarocks_bool("build --tree=/usr/invalid lpeg", env_variables))
      end
   end)

   it("LuaRocks build lpeg verbose", function()
      assert.is_true(run.luarocks_bool("build --verbose lpeg", env_variables))
   end)
end)
