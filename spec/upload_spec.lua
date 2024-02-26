local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

describe("luarocks upload #integration", function()

   describe("general tests", function()
      before_each(function()
         test_env.setup_specs(nil)
      end)

      it("with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("upload"))
      end)

      it("invalid rockspec", function()
         assert.is_false(run.luarocks_bool("upload invalid.rockspec"))
      end)

      it("api key invalid", function()
         assert.is_false(run.luarocks_bool("upload --api-key=invalid invalid.rockspec"))
      end)

      it("api key invalid and skip-pack", function()
         assert.is_false(run.luarocks_bool("upload --api-key=\"invalid\" --skip-pack " .. testing_paths.testing_server .. "/luasocket-${LUASOCKET}.rockspec"))
      end)

      it("force #unix", function()
         assert.is_false(run.luarocks_bool("upload --api-key=\"invalid\" --force " .. testing_paths.testing_server .. "/luasocket-${LUASOCKET}.rockspec"))
      end)
   end)

   describe("tests with Xavante server #mock", function()
      lazy_setup(function()
         test_env.setup_specs(nil, "mock")
         test_env.mock_server_init()
      end)

      lazy_teardown(test_env.mock_server_done)

      it("rockspec with api-key", function()
         assert.is_true(run.luarocks_bool("upload " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. test_env.openssl_dirs .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)

      it("#gpg rockspec with --sign", function()
         os.remove(testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec.asc")
         os.remove(testing_paths.testrun_dir .. "/a_rock-1.0-1.src.rock.asc")
         print(run.luarocks("upload " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. test_env.openssl_dirs .. " --api-key=123 --sign", {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)

      it("with .rockspec and .src.rock", function()
         assert.is_true(run.luarocks_bool("upload " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.src.rock " .. test_env.openssl_dirs, {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)

      it("with arguments .src.rock and .rockspec out of order", function()
         assert.is_false(run.luarocks_bool("upload " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.src.rock " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. test_env.openssl_dirs, {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)

      it("rockspec with api-key and skip-pack", function()
         assert.is_true(run.luarocks_bool("upload --skip-pack " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. test_env.openssl_dirs .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)
   end)
end)
