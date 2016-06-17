local path = require("luarocks.path")
local test_env = require("new_test/test_environment")

expose("LuaRocks path tests #blackbox #b_path", function()
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
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
