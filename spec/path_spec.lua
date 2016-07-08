local test_env = require("test/test_environment")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks path tests #blackbox #b_path", function()
   before_each(function()
      test_env.setup_specs()
   end)

   it("LuaRocks path bin", function()
      assert.is_true(run.luarocks_bool("path --bin"))
   end)

   it("LuaRocks path lr-path", function()
      assert.is_true(run.luarocks_bool("path --lr-path"))
   end)
   
   it("LuaRocks path lr-cpath", function()
      assert.is_true(run.luarocks_bool("path --lr-cpath"))
   end)
   
   it("LuaRocks path with tree", function()
      assert.is_true(run.luarocks_bool("path --tree=lua_modules"))
   end)
end)
