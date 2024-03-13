local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

local extra_rocks = {
   "/luasocket-${LUASOCKET}.src.rock",
}

describe("LuaRocks add tests #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("LuaRocks-admin add tests", function()
      it("invalid rock #ssh", function()
         assert.is_false(run.luarocks_admin_bool("--server=testing add invalid"))
      end)

      it("missing argument", function()
         assert.is_false(run.luarocks_admin_bool("--server=testing add"))
      end)

      it("invalid server", function()
         assert.is_false(run.luarocks_admin_bool("--server=invalid add " .. testing_paths.testing_server .. "/luasocket-${LUASOCKET}.src.rock"))
      end)

      it("invalid server #ssh", function()
         assert.is_true(run.luarocks_admin_bool("--server=testing add " .. testing_paths.testing_server .. "/luasocket-${LUASOCKET}.src.rock"))
      end)

      --TODO This test fails, sftp support not yet implemented
      it("invalid server", function()
         assert.is_false(run.luarocks_admin_bool("--server=testing add luasocket-${LUASOCKET}.src.rock", { LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/testing_config_sftp.lua" } ))
      end)

      it("split server url", function()
         assert.is_false(run.luarocks_admin_bool("--server=\"localhost@/tmp/luarocks_testing\" add " .. testing_paths.testing_server .. "/luasocket-${LUASOCKET}.src.rock"))
      end)
   end)
end)
