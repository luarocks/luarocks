local test_env = require("new_test/test_environment")
local new_version = require("luarocks.new_version")


expose("LuaRocks new_version tests #blackbox #b_new_version", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)
   
   it("LuaRocks new version with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("new_version"))
   end)
   it("LuaRocks new version invalid", function()
      assert.is_false(run.luarocks_bool("new_version invalid"))
   end)
end)
