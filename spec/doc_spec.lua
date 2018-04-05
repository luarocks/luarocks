local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
  "/luarepl-0.4-1.src.rock",
  "/c3-1.0-1.src.rock"
}

describe("LuaRocks doc tests #blackbox #b_doc", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("LuaRocks doc basic tests", function()
      it("LuaRocks doc with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("doc"))
      end)
      it("LuaRocks doc with invalid argument", function()
         assert.is_false(run.luarocks_bool("doc invalid"))
      end)
      it("LuaRocks doc with no homepage", function()
         assert.is_true(run.luarocks_bool("install c3"))
         assert.is_false(run.luarocks_bool("doc c3 --home"))
      end)
      it("LuaRocks doc with no home page and no doc folder", function()
         assert.is_true(run.luarocks_bool("install c3"))
         test_env.remove_dir(testing_paths.testing_sys_rocks .. "/c3/1.0-1/doc")
         assert.is_false(run.luarocks_bool("doc c3"))
      end)
      it("LuaRocks doc with no doc folder opening descript.homepage", function()
         assert.is_true(run.luarocks_bool("install luarepl"))
         test_env.remove_dir(testing_paths.testing_sys_rocks .. "/luarepl/0.4-1/doc")
         local output = run.luarocks("doc luarepl")
         assert.is.truthy(output:find("Local documentation directory not found"))
      end)
   end)

   describe("#namespaces", function()
      it("retrieves docs for a namespaced package from the command-line", function()
         assert(run.luarocks_bool("build a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("build a_rock --keep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert.match("a_rock 2.0", run.luarocks("doc a_user/a_rock"))
      end)
   end)
   
   describe("LuaRocks doc tests with flags", function()
      it("LuaRocks doc of installed luarepl", function()
         assert.is_true(run.luarocks_bool("install luarepl"))
         assert.is_true(run.luarocks_bool("doc luarepl"))
      end)

      it("LuaRocks doc of luacov and access its home page", function()
         assert.is_true(run.luarocks_bool("install luacov"))
         assert.is_true(run.luarocks_bool("doc luacov --home"))
      end)
      
      it("LuaRocks doc of luacov and list doc folder", function()
         assert.is_true(run.luarocks_bool("install luacov"))
         local output = assert.is.truthy(run.luarocks("doc luacov --list"))
         assert.is.truthy(output:find("/lib/luarocks/rocks%-.*/luacov/0.11.0%-1/doc/", 1))
      end)
      
      it("LuaRocks doc of luacov local", function()
         assert.is_true(run.luarocks_bool("install luacov"))
         assert.is_true(run.luarocks_bool("doc luacov --local"))
      end)
      
      it("LuaRocks doc of luacov porcelain", function()
         assert.is_true(run.luarocks_bool("install luacov"))
         assert.is_true(run.luarocks_bool("doc luacov --porcelain"))
      end)
   end)
end)


