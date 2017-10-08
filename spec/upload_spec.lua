local test_env = require("test/test_environment")
local test_mock_server = require("test/test_mock_server")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = test_mock_server.extra_rocks()

describe("LuaRocks upload tests #blackbox #b_upload", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
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
      before_each(test_mock_server.init)
      
      after_each(test_mock_server.done)

      it("LuaRocks upload rockspec with api-key", function()
         assert.is_true(run.luarocks_bool("upload " .. testing_paths.testing_dir .. "/testfiles/a_rock-1.0-1.rockspec " .. test_env.OPENSSL_DIRS .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testing_dir .. "/luarocks_site.lua"}))
      end)
      it("LuaRocks upload rockspec with api-key and skip-pack", function()
         assert.is_true(run.luarocks_bool("upload --skip-pack " .. testing_paths.testing_dir .. "/testfiles/a_rock-1.0-1.rockspec " .. test_env.OPENSSL_DIRS .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testing_dir .. "/luarocks_site.lua"}))
      end)
   end)
end)

