local doc = require("luarocks.doc")
local test_env = require("new_test/test_environment")


expose("LuaRocks doc tests #blackbox #b_doc", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      testing_paths = test_env.testing_paths
      run = test_env.run
   end)

   it("LuaRocks doc with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("doc"))
   end)
end)


