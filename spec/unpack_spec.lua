local unpack = require("luarocks.unpack")
local test_env = require("new_test/test_environment")


expose("LuaRocks unpack tests #blackbox #b_unpack", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   it("LuaRocks unpack with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("unpack"))
   end)
end)


