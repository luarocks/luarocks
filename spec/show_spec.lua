local test_env = require("test/test_environment")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks show tests #blackbox #b_show", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
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
      end)
      
      it("LuaRocks show modules of luacov", function()
         local output = run.luarocks("show --modules luacov")
      end)
      
      it("LuaRocks show dependencies of luacov", function()
         local output = run.luarocks("show --deps luacov")
      end)
      
      it("LuaRocks show rockspec of luacov", function()
         local output = run.luarocks("show --rockspec luacov")
      end)
      
      it("LuaRocks show mversion of luacov", function()
         local output = run.luarocks("show --mversion luacov")
      end)
      
      it("LuaRocks show rock tree of luacov", function()
         local output = run.luarocks("show --rock-tree luacov")
      end)
      
      it("LuaRocks show rock directory of luacov", function()
         local output = run.luarocks("show --rock-dir luacov")
      end)
   end)

   it("LuaRocks show old version of luacov", function()
      run.luarocks("install luacov 0.11.0")
      run.luarocks("show luacov 0.11.0")
   end)
end)
