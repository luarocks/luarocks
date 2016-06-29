local test_env = require("new_test/test_environment")
local lfs = require("lfs")

local extra_rocks = {
   "/lua-cjson-2.1.0-1.src.rock"
}

expose("LuaRocks upload tests #blackbox #b_upload", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
   end)

   it("LuaRocks upload with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("upload"))
   end)
   it("LuaRocks upload invalid rockspec", function()
      assert.is_false(run.luarocks_bool("upload invalid.rockspec"))
   end)
   it("LuaRocks upload api key invalid", function()
      assert.is_false(run.luarocks_bool("upload --api-key=invalid invalid.rockspec"))
   end)
   it("LuaRocks upload api key invalid and skip-pack", function()
      assert.is_false(run.luarocks_bool("upload --api-key=\"invalid\" --skip-pack luacov-0.11.0-1.rockspec"))
   end)
   it("LuaRocks upload force", function()
      assert.is_true(run.luarocks_bool("install lua-cjson"))
      assert.is_false(run.luarocks_bool("upload --api-key=\"invalid\" --force luacov-0.11.0-1.rockspec"))

      assert.is_true(run.luarocks_bool("install lua-cjson"))
   end)
end)


