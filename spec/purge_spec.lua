local test_env = require("test/test_environment")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

describe("LuaRocks purge tests #blackbox #b_purge", function()
   before_each(function()
      test_env.setup_specs()
   end)

   describe("LuaRocks purge basic tests", function()
      it("LuaRocks purge missing tree", function()
         assert.is_false(run.luarocks_bool("purge --tree=" .. testing_paths.testing_tree))
      end)
      it("LuaRocks purge tree with no string", function()
         assert.is_false(run.luarocks_bool("purge --tree=1"))
      end)
      it("LuaRocks purge tree with no string", function()
         assert.is_true(run.luarocks_bool("purge --tree=" .. testing_paths.testing_sys_tree))
      end)
      it("LuaRocks purge old versions tree", function()
         assert.is_true(run.luarocks_bool("purge --old-versions --tree=" .. testing_paths.testing_sys_tree))
      end)
   end)
end)


