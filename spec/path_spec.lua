local test_env = require("spec.util.test_env")
local run = test_env.run

describe("luarocks path #integration", function()
   before_each(function()
      test_env.setup_specs()
   end)

   it("runs", function()
      local output = run.luarocks("path")
      assert.match("LUA_PATH=", output)
      assert.match("LUA_CPATH=", output)
   end)

   if _VERSION:match("[23]") then
      local v = _VERSION:gsub("Lua (%d+)%.(%d+)", "%1_%2")

      it("with LUA_PATH_"..v, function()
         local output = run.luarocks("path", {
            ["LUA_PATH_"..v] = package.path,
         })
         assert.match("LUA_PATH_"..v.."=", output)
      end)

      it("with LUA_CPATH_"..v, function()
         local output = run.luarocks("path", {
            ["LUA_CPATH_"..v] = package.cpath,
         })
         assert.match("LUA_CPATH_"..v.."=", output)
      end)

      it("with LUA_PATH_"..v.." and LUA_CPATH_"..v, function()
         local output = run.luarocks("path", {
            ["LUA_PATH_"..v]  = package.path,
            ["LUA_CPATH_"..v] = package.cpath,
         })
         assert.match("LUA_PATH_"..v.."=", output)
         assert.match("LUA_CPATH_"..v.."=", output)
      end)

   end

   it("--bin", function()
      assert.is_true(run.luarocks_bool("path --bin"))
   end)

   it("--lr-path", function()
      assert.is_true(run.luarocks_bool("path --lr-path"))
   end)

   it("--lr-cpath", function()
      assert.is_true(run.luarocks_bool("path --lr-cpath"))
   end)

   it("--tree", function()
      assert.is_true(run.luarocks_bool("path --tree=lua_modules"))
   end)
end)
