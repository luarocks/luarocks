local test_env = require("test/test_environment")
local run = test_env.run

test_env.unload_luarocks()

local extra_rocks = {
"/lzlib-0.4.1.53-1.src.rock"
}

describe("LuaRocks search tests #blackbox #b_search", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("LuaRocks search with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("search"))
   end)

   it("LuaRocks search zlib", function()
      assert.is_true(run.luarocks_bool("search zlib"))
   end)
   
   it("LuaRocks search zlib 1.1", function()
      assert.is_true(run.luarocks_bool("search zlib 1.1"))
   end)
   
   it("LuaRocks search missing rock", function()
      assert.is_true(run.luarocks_bool("search missing_rock"))
   end)
   
   it("LuaRocks search with flag all", function()
      assert.is_true(run.luarocks_bool("search --all"))
   end)
end)
