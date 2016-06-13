local test_env = require("new_test/test_environment")
local lfs = require("lfs")

local run = _G.test_setup.run
local testing_paths = _G.test_setup.testing_paths
local env_variables = _G.test_setup.env_variables
local md5sums = _G.test_setup.md5sums

describe("Basic tests #blackbox #b_util", function()
   it("LuaRocks version", function()
      assert.is_true(run.luarocks_bool("--version", env_variables))
   end)

   it("LuaRocks unknown command", function()
      assert.is_false(run.luarocks_bool("unknown_command", env_variables))
   end)

   it("LuaRocks arguments fail", function()
      assert.is_false(run.luarocks_bool("--porcelain=invalid", env_variables))
      assert.is_false(run.luarocks_bool("--invalid-flag", env_variables))
      assert.is_false(run.luarocks_bool("--server", env_variables))
      assert.is_false(run.luarocks_bool("--server --porcelain", env_variables))
      assert.is_false(run.luarocks_bool("--invalid-flag=abc", env_variables))
      assert.is_false(run.luarocks_bool("invalid=5", env_variables))
   end)

   it("LuaRocks execute from not existing directory ", function()
      local main_path = lfs.currentdir()
      assert.is_true(lfs.mkdir("idontexist"))
      assert.is_true(lfs.chdir("idontexist"))
      local delete_path = lfs.currentdir()
      assert.is_true(os.remove(delete_path))

      assert.is_false(run.luarocks_bool(" ", env_variables))
      assert.is_true(lfs.chdir(main_path))
      assert.is_true(run.luarocks_bool(" ", env_variables))
   end)
end)
