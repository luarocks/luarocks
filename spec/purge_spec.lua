local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/say-1.0-1.src.rock",
}

describe("luarocks purge #integration", function()
   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("missing tree", function()
      assert.is_false(run.luarocks_bool("purge --tree=" .. testing_paths.testing_tree))
   end)
   it("tree with no string", function()
      assert.is_false(run.luarocks_bool("purge --tree="))
   end)
   it("tree with no string", function()
      assert.is_true(run.luarocks_bool("purge --tree=" .. testing_paths.testing_sys_tree))
   end)
   it("tree missing files", function()
      assert.is_true(run.luarocks_bool("install say 1.0"))
      test_env.remove_dir(testing_paths.testing_sys_tree .. "/share/lua/"..test_env.lua_version.."/say")
      assert.is_true(run.luarocks_bool("purge --tree=" .. testing_paths.testing_sys_tree))
      assert.is_false(test_env.exists(testing_paths.testing_sys_rocks .. "/say"))
   end)
   it("old versions tree", function()
      assert.is_true(run.luarocks_bool("purge --old-versions --tree=" .. testing_paths.testing_sys_tree))
   end)
end)
