local test_env = require("new_test/test_environment")
local lfs = require("lfs")

test_env.unload_luarocks()
local add = require("luarocks.add")

local extra_rocks = {
   "/luasocket-3.0rc1-1.src.rock",
   "/luasocket-3.0rc1-1.rockspec"
}

expose("LuaRocks add tests #blackbox #b_add", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      testing_paths = test_env.testing_paths
      run = test_env.run
   end)

   describe("LuaRocks-admin add tests", function()
      it("LuaRocks-admin add invalid rock #ssh", function()
         assert.is_false(run.luarocks_admin_bool("--server=testing add invalid"))
      end)
      it("LuaRocks-admin add missing argument", function()
         assert.is_false(run.luarocks_admin_bool("--server=testing add"))
      end)
      it("LuaRocks-admin add invalid server", function()
         assert.is_false(run.luarocks_admin_bool("--server=invalid add " .. testing_paths.testing_server .. "/luasocket-3.0rc1-1.src.rock"))
      end)
      it("LuaRocks-admin add invalid server #ssh", function()
         assert.is_true(run.luarocks_admin_bool("--server=testing add " .. testing_paths.testing_server .. "/luasocket-3.0rc1-1.src.rock"))
      end)
      --TODO This test fails, because we can't refresh the cache without a http url configured in upload_server
      it("LuaRocks-admin add invalid server", function() --?
         assert.is_false(run.luarocks_admin_bool("--server=testing add luasocket-3.0rc1-1.src.rock", { LUAROCKS_CONFIG = testing_paths.testing_dir .. "/testing_config_sftp.lua" } ))
      end)
      it("LuaRocks-admin add, split server url", function() --?
         assert.is_false(run.luarocks_admin_bool("--server=\"localhost@/tmp/luarocks_testing\" add " .. testing_paths.testing_server .. "luasocket-3.0rc1-1.src.rock"))
      end)
   end)
end)