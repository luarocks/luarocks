local test_env = require("test/test_environment")
local lfs = require("lfs")
local run = test_env.run

test_env.unload_luarocks()

local extra_rocks = {
   "/validate-args-1.5.4-1.rockspec"
}

describe("LuaRocks download tests #blackbox #b_download", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("LuaRocks download with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("download"))
   end)

   it("LuaRocks download invalid", function()
      assert.is_false(run.luarocks_bool("download invalid"))
   end)

   it("LuaRocks download all with delete downloaded files", function() --TODO maybe download --all more rocks
      assert.is_true(run.luarocks_bool("download --all validate-args"))
      assert.is.truthy(lfs.attributes("validate-args-1.5.4-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "validate--args--")
   end)
   
   it("LuaRocks download rockspec version", function()
      assert.is_true(run.luarocks_bool("download --rockspec validate-args 1.5.4-1"))
      assert.is.truthy(lfs.attributes("validate-args-1.5.4-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "validate--args--")
   end)
end)
