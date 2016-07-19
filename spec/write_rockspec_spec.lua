local test_env = require("test/test_environment")
local lfs = require("lfs")
local run = test_env.run

test_env.unload_luarocks()

describe("LuaRocks write_rockspec tests #blackbox #b_write_rockspec", function()

   before_each(function()
      test_env.setup_specs()
   end)

   describe("LuaRocks write_rockspec basic tests", function()
      it("LuaRocks write_rockspec with no flags/arguments", function()
         assert.is_true(run.luarocks_bool("write_rockspec"))
         os.remove("luarocks-scm-1.rockspec")
      end)

      it("LuaRocks write_rockspec with invalid argument", function()
         assert.is_false(run.luarocks_bool("write_rockspec invalid"))
      end)
      
      it("LuaRocks write_rockspec invalid zip", function()
         assert.is_false(run.luarocks_bool("write_rockspec http://example.com/invalid.zip"))
      end)
   end)

   describe("LuaRocks write_rockspec more complex tests", function()
      it("LuaRocks write_rockspec git luarocks", function()
         assert.is_true(run.luarocks_bool("write_rockspec git://github.com/keplerproject/luarocks"))
         assert.is.truthy(lfs.attributes("luarocks-scm-1.rockspec"))
         assert.is_true(os.remove("luarocks-scm-1.rockspec"))
      end)
      
      it("LuaRocks write_rockspec git luarocks --tag=v2.3.0", function()
         assert.is_true(run.luarocks_bool("write_rockspec git://github.com/keplerproject/luarocks --tag=v2.3.0"))
         assert.is.truthy(lfs.attributes("luarocks-2.3.0-1.rockspec"))
         assert.is_true(os.remove("luarocks-2.3.0-1.rockspec"))
      end)
      
      it("LuaRocks write_rockspec git luarocks with format flag", function()
         assert.is_true(run.luarocks_bool("write_rockspec git://github.com/mbalmer/luarocks --rockspec-format=1.1 --lua-version=5.1,5.2"))
         assert.is.truthy(lfs.attributes("luarocks-scm-1.rockspec"))
         assert.is_true(os.remove("luarocks-scm-1.rockspec"))
      end)
      
      it("LuaRocks write_rockspec git luarocks with full flags", function()
         assert.is_true(run.luarocks_bool("write_rockspec git://github.com/mbalmer/luarocks --lua-version=5.1,5.2 --license=\"MIT/X11\" "
                                             .. " --homepage=\"http://www.luarocks.org\" --summary=\"A package manager for Lua modules\" "))
         assert.is.truthy(lfs.attributes("luarocks-scm-1.rockspec"))
         assert.is_true(os.remove("luarocks-scm-1.rockspec"))
      end)
      
      it("LuaRocks write_rockspec rockspec via http", function()
         assert.is_true(run.luarocks_bool("write_rockspec http://luarocks.org/releases/luarocks-2.1.0.tar.gz --lua-version=5.1"))
         assert.is.truthy(lfs.attributes("luarocks-2.1.0-1.rockspec"))
         assert.is_true(os.remove("luarocks-2.1.0-1.rockspec"))
      end)
      
      it("LuaRocks write_rockspec base dir, luassert.tar.gz via https", function()
         assert.is_true(run.luarocks_bool("write_rockspec https://github.com/downloads/Olivine-Labs/luassert/luassert-1.2.tar.gz --lua-version=5.1"))
         assert.is.truthy(lfs.attributes("luassert-1.2-1.rockspec"))
         assert.is_true(os.remove("luassert-1.2-1.rockspec"))
      end)
      
      it("LuaRocks write_rockspec git luafcgi with many flags", function()
         assert.is_true(run.luarocks_bool("write_rockspec git://github.com/mbalmer/luafcgi --lib=fcgi --license=\"3-clause BSD\" " .. "--lua-version=5.1,5.2"))
         assert.is.truthy(lfs.attributes("luafcgi-scm-1.rockspec")) -- TODO maybe read it content and find arguments from flags?
         assert.is_true(os.remove("luafcgi-scm-1.rockspec"))
      end)
   end)
end)
