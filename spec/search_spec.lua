local test_env = require("spec.util.test_env")
local run = test_env.run

local extra_rocks = {
"/lzlib-0.4.1.53-1.src.rock"
}

describe("luarocks search #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("search"))
   end)

   it("zlib", function()
      assert.is_true(run.luarocks_bool("search zlib"))
   end)

   it("zlib 1.1", function()
      assert.is_true(run.luarocks_bool("search zlib 1.1"))
   end)

   it("missing rock", function()
      assert.is_true(run.luarocks_bool("search missing_rock"))
   end)

   it("with flag all", function()
      assert.is_true(run.luarocks_bool("search --all"))
   end)
end)
