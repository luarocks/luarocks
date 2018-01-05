local test_env = require("test/test_environment")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks path tests #blackbox #b_path", function()
   before_each(function()
      test_env.setup_specs()
   end)

   it("LuaRocks path", function()
      local output = run.luarocks("path")
      assert.match("LUA_PATH=", output)
      assert.match("LUA_CPATH=", output)
   end)

   if _VERSION:match("[23]") then
      local v = _VERSION:gsub("Lua (%d+)%.(%d+)", "%1_%2")
   
      it("LuaRocks path with LUA_PATH_"..v, function()
         local output = run.luarocks("path", {
            ["LUA_PATH_"..v] = package.path,
         })
         assert.match("LUA_PATH_"..v.."=", output)
      end)

      it("LuaRocks path with LUA_CPATH_"..v, function()
         local output = run.luarocks("path", {
            ["LUA_CPATH_"..v] = package.cpath,
         })
         assert.match("LUA_CPATH_"..v.."=", output)
      end)

      it("LuaRocks path with LUA_PATH_"..v.." and LUA_CPATH_"..v, function()
         local output = run.luarocks("path", {
            ["LUA_PATH_"..v]  = package.path,
            ["LUA_CPATH_"..v] = package.cpath,
         })
         assert.match("LUA_PATH_"..v.."=", output)
         assert.match("LUA_CPATH_"..v.."=", output)
      end)

   end

   it("LuaRocks path bin", function()
      assert.is_true(run.luarocks_bool("path --bin"))
   end)

   it("LuaRocks path lr-path", function()
      assert.is_true(run.luarocks_bool("path --lr-path"))
   end)
   
   it("LuaRocks path lr-cpath", function()
      assert.is_true(run.luarocks_bool("path --lr-cpath"))
   end)
   
   it("LuaRocks path with tree", function()
      assert.is_true(run.luarocks_bool("path --tree=lua_modules"))
   end)
end)
