local test_env = require("test/test_environment")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   -- rocks needed for mock-server
   "/copas-2.0.1-1.src.rock",
   "/coxpcall-1.16.0-1.src.rock",
   "/dkjson-2.5-2.src.rock",
   "/luafilesystem-1.6.3-1.src.rock",
   "/luasec-0.6-1.rockspec",
   "/luasocket-3.0rc1-2.src.rock",
   "/luasocket-3.0rc1-2.rockspec",
   "/restserver-0.1-1.src.rock",
   "/restserver-xavante-0.2-1.src.rock",
   "/rings-1.3.0-1.src.rock",
   "/wsapi-1.6.1-1.src.rock",
   "/wsapi-xavante-1.6.1-1.src.rock",
   "/xavante-2.4.0-1.src.rock"
}

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
      before_each(function()
         assert.is_true(test_env.need_rock("restserver-xavante"))
         local final_command = test_env.execute_helper(testing_paths.lua .. " " .. testing_paths.testing_dir .. "/mock-server.lua &", true, test_env.env_variables)
         os.execute(final_command)
      end)
      
      after_each(function()
         os.execute("curl localhost:8080/shutdown")
      end)

      it("LuaRocks upload rockspec with api-key", function()
         assert.is_true(run.luarocks_bool("upload " .. testing_paths.testing_server .. "/luasocket-3.0rc1-2.rockspec " .. test_env.OPENSSL_DIRS .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testing_dir .. "/luarocks_site.lua"}))
      end)
      it("LuaRocks upload rockspec with api-key and skip-pack", function()
         assert.is_true(run.luarocks_bool("upload --skip-pack " .. testing_paths.testing_server .. "/luasocket-3.0rc1-2.rockspec " .. test_env.OPENSSL_DIRS .. " --api-key=123", {LUAROCKS_CONFIG = testing_paths.testing_dir .. "/luarocks_site.lua"}))
      end)
   end)
end)


