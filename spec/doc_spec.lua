local test_env = require("new_test/test_environment")
local lfs = require("lfs")

local extra_rocks = {
  "/luarepl-0.4-1.src.rock"
}

expose("LuaRocks doc tests #blackbox #b_doc", function()   
   before_each(function()
      test_env.setup_specs(extra_rocks)
      testing_paths = test_env.testing_paths
      run = test_env.run
   end)

   describe("LuaRocks doc basic tests", function()
      it("LuaRocks doc with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("doc"))
      end)
      it("LuaRocks doc with invalid argument", function()
         assert.is_false(run.luarocks_bool("doc invalid"))
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
         assert.is.truthy(output:find("/lib/luarocks/rocks/luacov/0.11.0--1/doc/"))
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


