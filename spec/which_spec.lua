local test_env = require("spec.util.test_env")
local run = test_env.run
local P = test_env.P

local extra_rocks = {
   "/say-1.2-1.src.rock",
}

describe("luarocks which #integration", function()

   lazy_setup(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("fails on missing arguments", function()
      local output = run.luarocks("which")
      assert.match("missing argument 'modname'", output, 1, true)
   end)

   it("finds modules found in package.path", function()
      assert.is_true(run.luarocks_bool("install say 1.2"))
      local output = run.luarocks("which say")
      assert.match(P"say/init.lua", output, 1, true)
      assert.match("provided by say 1.2-1", output, 1, true)
   end)

   it("finds modules found in package.path", function()
      run.luarocks("install ")
      local output = run.luarocks("which luarocks.loader")
      assert.match("luarocks/loader.lua", output, 1, true)
      assert.match("not installed as a rock", output, 1, true)
   end)

   it("report modules not found", function()
      local output = run.luarocks("which asdfgaoeui")
      assert.match("Module 'asdfgaoeui' not found", output, 1, true)
   end)

end)
