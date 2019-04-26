local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

describe("LuaRocks upload tests #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   it("LuaRocks upload with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("upload"))
   end)

   it("LuaRocks upload invalid rockspec", function()
      assert.is_false(run.luarocks_bool("upload invalid.rockspec"))
   end)
   
   it("LuaRocks upload api key invalid", function()
      assert.is_false(run.luarocks_bool("upload --api-key=invalid invalid.rockspec"))
   end)
   
   it("LuaRocks upload api key invalid and skip-pack", function()
      assert.is_false(run.luarocks_bool("upload --api-key=\"invalid\" --skip-pack " .. testing_paths.testing_server .. "/luasocket-3.0rc1-2.rockspec"))
   end)
   
   it("LuaRocks upload force #unix", function()
      assert.is_true(test_env.need_rock("dkjson"))
      assert.is_false(run.luarocks_bool("upload --api-key=\"invalid\" --force " .. testing_paths.testing_server .. "/luasocket-3.0rc1-2.rockspec"))
   end)

   describe("LuaRocks upload tests with Xavante server #mock", function()
      before_each(test_env.mock_server_init)
      
      after_each(test_env.mock_server_done)

      it("LuaRocks upload rockspec with api-key", function()
         assert.is_true(run.luarocks_bool("upload " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. test_env.openssl_dirs .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)

      it("#gpg rockspec with --sign", function()
         os.remove(testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec.asc")
         os.remove(testing_paths.testrun_dir .. "/a_rock-1.0-1.src.rock.asc")
         print(run.luarocks("upload " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. test_env.openssl_dirs .. " --api-key=123 --sign", {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)

      it("rockspec with api-key and skip-pack", function()
         assert.is_true(run.luarocks_bool("upload --skip-pack " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec " .. test_env.openssl_dirs .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/luarocks_site.lua"}))
      end)
   end)
end)
