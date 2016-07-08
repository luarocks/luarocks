local test_env = require("test/test_environment")

test_env.unload_luarocks()

expose("LuaRocks make_manifest tests #blackbox #b_make_manifest", function()
	
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   describe("LuaRocks-admin make manifest tests", function()
      it("LuaRocks-admin make manifest", function()
         assert.is_true(run.luarocks_admin_bool("make_manifest"))
      end)
   end)
end)
