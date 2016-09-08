local test_env = require("test/test_environment")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/lmathx-20120430.51-1.src.rock",
   "/lmathx-20120430.51-1.rockspec",
   "/lmathx-20120430.52-1.src.rock",
   "/lmathx-20120430.52-1.rockspec",
   "/lmathx-20150505-1.src.rock",
   "/lmathx-20150505-1.rockspec",
   "/lpeg-1.0.0-1.rockspec",
   "/lpeg-1.0.0-1.src.rock",
   "/lpty-1.0.1-1.src.rock",
   "/luadoc-3.0.1-1.src.rock",
   "/luafilesystem-1.6.3-1.src.rock",
   "/lualogging-1.3.0-1.src.rock",
   "/luarepl-0.4-1.src.rock",
   "/luasec-0.6-1.rockspec",
   "/luasocket-3.0rc1-2.src.rock",
   "/luasocket-3.0rc1-2.rockspec",
   "/lxsh-0.8.6-2.src.rock",
   "/lxsh-0.8.6-2.rockspec",
   "/stdlib-41.0.0-1.src.rock",
   "/validate-args-1.5.4-1.rockspec"
}

describe("LuaRocks build tests #blackbox #b_build", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("LuaRocks build - basic testing set", function()
      it("LuaRocks build with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("build"))
      end)
      
      it("LuaRocks build invalid", function()
         assert.is_false(run.luarocks_bool("build invalid"))
      end)
   end)

   describe("LuaRocks build - building lpeg with flags", function()
      it("LuaRocks build fail build permissions", function()
         if test_env.TEST_TARGET_OS == "osx" or test_env.TEST_TARGET_OS == "linux" then
            assert.is_false(run.luarocks_bool("build --tree=/usr lpeg"))
         end
      end)
      
      it("LuaRocks build fail build permissions parent", function()
         if test_env.TEST_TARGET_OS == "osx" or test_env.TEST_TARGET_OS == "linux" then
            assert.is_false(run.luarocks_bool("build --tree=/usr/invalid lpeg"))
         end
      end)
      
      it("LuaRocks build lpeg verbose", function()
         assert.is_true(run.luarocks_bool("build --verbose lpeg"))
      end)
      
      it("LuaRocks build lpeg branch=master", function()
         assert.is_true(run.luarocks_bool("build --branch=master lpeg"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      end)
      
      it("LuaRocks build lpeg deps-mode=123", function()
         assert.is_false(run.luarocks_bool("build --deps-mode=123 lpeg --verbose"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      end)
      
      it("LuaRocks build lpeg only-sources example", function()
         assert.is_true(run.luarocks_bool("download --rockspec lpeg"))
         assert.is_false(run.luarocks_bool("build --only-sources=\"http://example.com\" lpeg-1.0.0-1.rockspec"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))

         assert.is_true(run.luarocks_bool("download --source lpeg"))
         assert.is_true(run.luarocks_bool("build --only-sources=\"http://example.com\" lpeg-1.0.0-1.src.rock"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))

         assert.is_true(os.remove("lpeg-1.0.0-1.rockspec"))
         assert.is_true(os.remove("lpeg-1.0.0-1.src.rock"))
      end)
      
      it("LuaRocks build lpeg with empty tree", function()
         assert.is_false(run.luarocks_bool("build --tree=\"\" lpeg"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      end)
   end)

   describe("LuaRocks build - basic builds", function()
      it("LuaRocks build luadoc", function()
         assert.is_true(run.luarocks_bool("build luadoc"))
      end)
      
      it("LuaRocks build luacov diff version", function()
         assert.is_true(run.luarocks_bool("build luacov 0.11.0-1"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luacov/0.11.0-1/luacov-0.11.0-1.rockspec"))
      end)
      
      it("LuaRocks build command stdlib", function()
         assert.is_true(run.luarocks_bool("build stdlib"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/stdlib/41.0.0-1/stdlib-41.0.0-1.rockspec"))
      end)
      
      it("LuaRocks build install bin luarepl", function()
         assert.is_true(run.luarocks_bool("build luarepl"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luarepl/0.4-1/luarepl-0.4-1.rockspec"))
      end)
      
      it("LuaRocks build supported platforms lpty", function()
         if test_env.TEST_TARGET_OS == "windows" then
            assert.is_false(run.luarocks_bool("build lpty")) --Error: This rockspec for lpty does not support win32, windows platforms
         else
            assert.is_true(run.luarocks_bool("build lpty"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpty/1.0.1-1/lpty-1.0.1-1.rockspec"))
         end
      end)
      
      it("LuaRocks build luasec with skipping dependency checks", function()
         assert.is_true(run.luarocks_bool("build luasec " .. test_env.OPENSSL_DIRS .. " --nodeps"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasec/0.6-1/luasec-0.6-1.rockspec"))
      end)
      
      it("LuaRocks build lmathx deps partial match", function()
         assert.is_true(run.luarocks_bool("build lmathx"))

         if test_env.LUA_V == "5.1" or test_env.LUAJIT_V then
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lmathx/20120430.51-1/lmathx-20120430.51-1.rockspec"))
         elseif test_env.LUA_V == "5.2" then
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lmathx/20120430.52-1/lmathx-20120430.52-1.rockspec"))
         elseif test_env.LUA_V == "5.3" then
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lmathx/20150505-1/lmathx-20150505-1.rockspec"))
         end
      end)
   end)

   describe("LuaRocks build - more complex tests", function()
      if test_env.TYPE_TEST_ENV == "full" then
         it("LuaRocks build luacheck show downloads test_config", function()
            local output = run.luarocks("build luacheck", { LUAROCKS_CONFIG = testing_paths.testing_dir .. "/testing_config_show_downloads.lua"} )
            assert.is.truthy(output:match("%.%.%."))
         end)
      end

      it("LuaRocks build luasec only deps", function()
         assert.is_true(run.luarocks_bool("build luasec " .. test_env.OPENSSL_DIRS .. " --only-deps"))
         assert.is_false(run.luarocks_bool("show luasec"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasec/0.6-1/luasec-0.6-1.rockspec"))
      end)
      
      it("LuaRocks build only deps of downloaded rockspec of lxsh", function()
         assert.is_true(run.luarocks_bool("download --rockspec lxsh 0.8.6-2"))
         assert.is.truthy(run.luarocks("build lxsh-0.8.6-2.rockspec --only-deps"))
         assert.is_false(run.luarocks_bool("show lxsh"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
         assert.is_true(os.remove("lxsh-0.8.6-2.rockspec"))
      end)

      it("LuaRocks build only deps of downloaded rock of lxsh", function()
         assert.is_true(run.luarocks_bool("download --source lxsh 0.8.6-2"))
         assert.is.truthy(run.luarocks("build lxsh-0.8.6-2.src.rock --only-deps"))
         assert.is_false(run.luarocks_bool("show lxsh"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
         assert.is_true(os.remove("lxsh-0.8.6-2.src.rock"))
      end)

      it("LuaRocks build no https", function()
         assert.is_true(run.luarocks_bool("download --rockspec validate-args 1.5.4-1"))
         assert.is_true(run.luarocks_bool("build validate-args-1.5.4-1.rockspec"))

         assert.is.truthy(run.luarocks("show validate-args"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/validate-args/1.5.4-1/validate-args-1.5.4-1.rockspec"))

         assert.is_true(os.remove("validate-args-1.5.4-1.rockspec"))
      end)
      
      it("LuaRocks build with https", function()
         assert.is_true(run.luarocks_bool("download --rockspec validate-args 1.5.4-1"))
         assert.is_true(run.luarocks_bool("install luasec " .. test_env.OPENSSL_DIRS))
         
         assert.is_true(run.luarocks_bool("build validate-args-1.5.4-1.rockspec"))
         assert.is.truthy(run.luarocks("show validate-args"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/validate-args/1.5.4-1/validate-args-1.5.4-1.rockspec"))
         assert.is_true(os.remove("validate-args-1.5.4-1.rockspec"))
      end)

      it("LuaRocks build missing external", function()
         assert.is_false(run.luarocks_bool("build " .. testing_paths.testing_dir .. "/testfiles/missing_external-0.1-1.rockspec INEXISTENT_INCDIR=\"/invalid/dir\""))
      end)
      
      it("LuaRocks build invalid patch", function()
         assert.is_false(run.luarocks_bool("build " .. testing_paths.testing_dir .. "/testfiles/invalid_patch-0.1-1.rockspec"))
      end)
   end)
end)
