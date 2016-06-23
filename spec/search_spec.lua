local search = require("luarocks.search")
local test_env = require("new_test/test_environment")

local extra_rocks = {
"/lzlib-0.4.1.53-1.src.rock"
}

expose("LuaRocks search tests #blackbox #b_search", function()
   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
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
   it("LuaRocks search zlib", function()
      local num = 123
      assert.is_true(run.luarocks_bool("search " .. num))
   end)
end)