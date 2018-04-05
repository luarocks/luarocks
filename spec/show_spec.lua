local test_env = require("spec.util.test_env")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks show tests #blackbox #b_show", function()
   
   before_each(function()
      test_env.setup_specs()
   end)

   it("LuaRocks show with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("show"))
   end)
   
   describe("LuaRocks show basic tests with flags", function()
      it("LuaRocks show invalid", function()
         assert.is_false(run.luarocks_bool("show invalid"))
      end)
      
      it("LuaRocks show luacov", function()
         local output = run.luarocks("show luacov")
         assert.is.truthy(output:match("LuaCov"))
      end)

      it("LuaRocks show luacov with uppercase name", function()
         local output = run.luarocks("show LuaCov")
         assert.is.truthy(output:match("LuaCov"))
      end)
      
      it("LuaRocks show modules of luacov", function()
         local output = run.luarocks("show --modules luacov")
         assert.match("luacov.*luacov.defaults.*luacov.reporter.*luacov.reporter.default.*luacov.runner.*luacov.stats.*luacov.tick", output)
      end)
      
      it("LuaRocks show dependencies of luacov", function()
         local output = run.luarocks("show --deps luacov")
      end)
      
      it("LuaRocks show rockspec of luacov", function()
         local output = run.luarocks("show --rockspec luacov")
         assert.is.truthy(output:match("luacov--0.11.0--1.rockspec"))
      end)
      
      it("LuaRocks show mversion of luacov", function()
         local output = run.luarocks("show --mversion luacov")
         assert.is.truthy(output:match("0.11.0--1"))
      end)
      
      it("LuaRocks show rock tree of luacov", function()
         local output = run.luarocks("show --rock-tree luacov")
      end)
      
      it("LuaRocks show rock directory of luacov", function()
         local output = run.luarocks("show --rock-dir luacov")
      end)

      it("LuaRocks show issues URL of luacov", function()
         local output = run.luarocks("show --issues luacov")
      end)
      
      it("LuaRocks show labels of luacov", function()
         local output = run.luarocks("show --labels luacov")
      end)
   end)

   it("LuaRocks show old version of luacov", function()
      run.luarocks("install luacov 0.11.0")
      run.luarocks_bool("show luacov 0.11.0")
   end)
end)
