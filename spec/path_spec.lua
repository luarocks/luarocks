local test_env = require("spec.util.test_env")
local run = test_env.run

test_env.unload_luarocks()

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

   it("--project-tree", function()
      local path1 = "/share/lua/5%." .. test_env.lua_version:sub(3, 3) .. "/%?%.lua"
      local path2 = "/share/lua/5%." .. test_env.lua_version:sub(3, 3) .. "/%?/init%.lua"

      local path = run.luarocks("path --project-tree=foo")
      assert.truthy(path:find("foo" .. path1))
      assert.truthy(path:find("foo" .. path2))

      path = run.luarocks("path --project-tree=foo --tree=bar")
      assert.falsy(path:find("foo" .. path1))
      assert.falsy(path:find("foo" .. path2))
      assert.truthy(path:find("bar" .. path1))
      assert.truthy(path:find("bar" .. path2))
   end)
end)
