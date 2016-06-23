local upload = require("luarocks.upload")
local test_env = require("new_test/test_environment")


expose("LuaRocks upload tests #blackbox #b_upload", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   it("LuaRocks upload with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("upload"))
   end)
end)


