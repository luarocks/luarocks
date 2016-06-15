local download = require("luarocks.download")
local test_env = require("new_test/test_environment")
local lfs = require("lfs")

extra_rocks={
"/validate-args-1.5.4-1.rockspec"
}

expose("LuaRocks download tests #blackbox #b_download", function()
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   it("LuaRocks download with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("download"))
   end)
   it("LuaRocks download invalid", function()
      assert.is_false(run.luarocks_bool("download invalid"))
   end)
   it("LuaRocks download all", function()
      assert.is_true(run.luarocks_bool("download --all validate-args"))
      test_env.remove_files(lfs.currentdir(), "validate--args--")
   end)
end)
