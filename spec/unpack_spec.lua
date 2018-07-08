local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/cprint-0.1-2.src.rock",
   "/cprint-0.1-2.rockspec",
   "/luazip-1.2.4-1.rockspec"
}

describe("LuaRocks unpack tests #integration", function()
   
   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("LuaRocks unpack basic fail tests", function()
      it("LuaRocks unpack with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("unpack"))
      end)
      
      it("LuaRocks unpack with invalid rockspec", function()
         assert.is_false(run.luarocks_bool("unpack invalid.rockspec"))
      end)
      
      it("LuaRocks unpack with invalid patch", function()
         assert.is_false(run.luarocks_bool("unpack " .. testing_paths.fixtures_dir .. "/invalid_patch-0.1-1.rockspec"))
      end)
   end)

   describe("LuaRocks unpack more complex tests", function()
      it("LuaRocks unpack download", function()
         assert.is_true(run.luarocks_bool("unpack cprint"))
         test_env.remove_dir("cprint-0.1-2")
      end)
      
      it("LuaRocks unpack src", function()
         assert.is_true(run.luarocks_bool("download --source cprint"))
         assert.is_true(run.luarocks_bool("unpack cprint-0.1-2.src.rock"))
         os.remove("cprint-0.1-2.src.rock")
         test_env.remove_dir("cprint-0.1-2")
      end)
      
      it("LuaRocks unpack src", function()
         assert.is_true(run.luarocks_bool("download --rockspec cprint"))
         assert.is_true(run.luarocks_bool("unpack cprint-0.1-2.rockspec"))
         os.remove("cprint-0.1-2.rockspec")
         os.remove("lua-cprint")
         test_env.remove_dir("cprint-0.1-2")
      end)

      -- #595 luarocks unpack of a git:// rockspec fails to copy the rockspec
      it("LuaRocks unpack git:// rockspec", function()
         assert.is_true(run.luarocks_bool("download --rockspec luazip"))
         assert.is_true(run.luarocks_bool("unpack luazip-1.2.4-1.rockspec"))
         assert.is_truthy(lfs.attributes("luazip-1.2.4-1/luazip/luazip-1.2.4-1.rockspec"))
         test_env.remove_dir("luazip-1.2.4-1")
      end)

      it("LuaRocks unpack binary", function()
         assert.is_true(run.luarocks_bool("build cprint"))
         assert.is_true(run.luarocks_bool("pack cprint"))
         assert.is_true(run.luarocks_bool("unpack cprint-0.1-2." .. test_env.platform .. ".rock"))
         test_env.remove_dir("cprint-0.1-2")
         os.remove("cprint-0.1-2." .. test_env.platform .. ".rock")
      end)
   end)
end)
