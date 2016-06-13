local download = require("luarocks.download")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

describe("LuaRocks download tests #blackbox #b_download", function()
   before_each(function()
      test_env.reset_environment(testing_paths, md5sums)
   end)

   it("LuaRocks download with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("download", env_variables))
   end)
   it("LuaRocks download invalid", function()
      assert.is_false(run.luarocks_bool("download invalid", env_variables))
   end)
   it("LuaRocks download all", function()
      assert.is_true(run.luarocks_bool("download --all validate-args", env_variables))
      test_env.remove_files(lfs.currentdir(), "validate--args--")
   end)
end)
