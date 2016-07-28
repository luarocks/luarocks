local test_env = require("test/test_environment")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/validate-args-1.5.4-1.rockspec"
}

describe("LuaRocks lint tests #blackbox #b_lint", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("LuaRocks lint with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("lint"))
   end)

   it("LuaRocks lint invalid argument", function()
      assert.is_false(run.luarocks_bool("lint invalid"))
   end)
   
   it("LuaRocks lint OK", function()
      assert.is_true(run.luarocks_bool("download --rockspec validate-args 1.5.4-1"))
      local output = run.luarocks("lint validate-args-1.5.4-1.rockspec")
      assert.are.same(output, "")
      assert.is_true(os.remove("validate-args-1.5.4-1.rockspec"))
   end)
   
   describe("LuaRocks lint mismatch set", function()
      it("LuaRocks lint mismatch string", function()
         assert.is_false(run.luarocks_bool("lint " .. testing_paths.testing_dir .. "/testfiles/type_mismatch_string-1.0-1.rockspec"))
      end)
   
      it("LuaRocks lint mismatch version", function()
         assert.is_false(run.luarocks_bool("lint " .. testing_paths.testing_dir .. "/testfiles/type_mismatch_version-1.0-1.rockspec"))
      end)
   
      it("LuaRocks lint mismatch table", function()
         assert.is_false(run.luarocks_bool("lint " .. testing_paths.testing_dir .. "/testfiles/type_mismatch_table-1.0-1.rockspec"))
      end)
   
      it("LuaRocks lint mismatch no build table", function()
         assert.is_false(run.luarocks_bool("lint " .. testing_paths.testing_dir .. "/testfiles/no_build_table-1.0-1.rockspec"))
      end)
   end)
end)
