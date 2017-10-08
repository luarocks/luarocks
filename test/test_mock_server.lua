--- Utility module to launch the mock-server from within test spec files.
local test_mock_server = {}

local assert = require("luassert")
local test_env = require("test/test_environment")
local testing_paths = test_env.testing_paths

function test_mock_server.extra_rocks(more)
   local rocks = {
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
   if more then
      for _, rock in ipairs(more) do
         table.insert(rocks, rock)
      end
   end
   return rocks
end

function test_mock_server.init()
   assert.is_true(test_env.need_rock("restserver-xavante"))
   local final_command = test_env.execute_helper(testing_paths.lua .. " " .. testing_paths.testing_dir .. "/mock-server.lua &", true, test_env.env_variables)
   os.execute(final_command)
end

function test_mock_server.done()
   os.execute("curl localhost:8080/shutdown")
end

return test_mock_server
