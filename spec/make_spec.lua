local make = require("luarocks.make")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

describe("LuaRocks #whitebox_make", function()
   it("trivial_test #old", function()
      assert.are.same(1,1)
   end)
end)

describe("LuaRocks make tests #blackbox #b_make", function()
   it("LuaRocks make with no flags/arguments", function()
   	print(lfs.currentdir())
      assert.is_false(run.luarocks_bool("make", env_variables))
   end)
end)