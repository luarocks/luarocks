local write_rockspec = require("luarocks.write_rockspec")
local test_env = require("new_test/test_environment")


expose("LuaRocks write_rockspec tests #blackbox #b_write_rockspec", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   it("LuaRocks write_rockspec with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("write_rockspec"))
   end)
end)


