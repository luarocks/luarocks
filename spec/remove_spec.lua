local remove = require("luarocks.remove")
local test_env = require("new_test/test_environment")


expose("LuaRocks remove tests #blackbox #b_remove", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   it("LuaRocks remove with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("remove"))
   end)
end)


