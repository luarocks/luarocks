local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables
local V = test_env.V
local P = test_env.P

local extra_rocks = {
   "/abelhas-1.1-1.src.rock",
   "/copas-${COPAS}.src.rock",
   "/coxpcall-1.16.0-1.src.rock",
   "/coxpcall-1.16.0-1.rockspec",
   "/luafilesystem-${LUAFILESYSTEM}.src.rock",
   "/luafilesystem-${LUAFILESYSTEM_OLD}.src.rock",
}

describe("luarocks remove #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("basic tests", function()
      it("with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("remove"))
      end)

      it("invalid rock", function()
         assert.is_false(run.luarocks_bool("remove invalid.rock"))
      end)

      it("missing rock", function()
         assert.is_false(run.luarocks_bool("remove missing_rock"))
      end)

      it("invalid argument", function()
         assert.is_false(run.luarocks_bool("remove luacov --deps-mode"))
      end)

      it("built abelhas", function()
         assert.is_true(run.luarocks_bool("build abelhas 1.1"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/abelhas"))
         assert.is_true(run.luarocks_bool("remove abelhas 1.1"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/abelhas"))
      end)

      it("built abelhas with uppercase name", function()
         assert.is_true(run.luarocks_bool("build abelhas 1.1"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/abelhas"))
         assert.is_true(run.luarocks_bool("remove Abelhas 1.1"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/abelhas"))
      end)
   end)

   describe("more complex tests", function()
      before_each(function()
         assert.is.truthy(test_env.need_rock("coxpcall"))
      end)

      it("fail, break dependencies", function()
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/coxpcall"))
         assert.is_true(run.luarocks_bool("build copas"))

         assert.is_false(run.luarocks_bool("remove coxpcall"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/coxpcall"))
      end)

      it("force", function()
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/coxpcall"))
         assert.is_true(run.luarocks_bool("build copas"))

         local output = run.luarocks("remove --force coxpcall")
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/coxpcall"))
         assert.is.truthy(output:find("Checking stability of dependencies"))
      end)

      it("force fast", function()
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/coxpcall"))
         assert.is_true(run.luarocks_bool("build copas"))

         local output = run.luarocks("remove --force-fast coxpcall")
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/coxpcall"))
         assert.is.falsy(output:find("Checking stability of dependencies"))
      end)

      it("restores old versions", function()
         local libdir = P(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION)

         assert.is_true(run.luarocks_bool("install luafilesystem ${LUAFILESYSTEM_OLD_V}"))
         assert.is.truthy(lfs.attributes(libdir.."/lfs."..test_env.lib_extension))

         if test_env.TEST_TARGET_OS ~= "windows" then
            local fd = io.open(libdir.."/lfs."..test_env.lib_extension, "r")
            assert(fd:read("*a"):match(V"LuaFileSystem ${LUAFILESYSTEM_OLD_V}", 1, true))
            fd:close()
         end

         local suffix = (V"${LUAFILESYSTEM_OLD}"):gsub("[%.%-]", "_")

         assert.is_true(run.luarocks_bool("install luafilesystem ${LUAFILESYSTEM_V} --keep"))
         assert.is.truthy(lfs.attributes(libdir.."/lfs."..test_env.lib_extension))
         assert.is.truthy(lfs.attributes(libdir.."/luafilesystem_"..suffix.."-lfs."..test_env.lib_extension))

         if test_env.TEST_TARGET_OS ~= "windows" then
            local fd = io.open(libdir.."/lfs."..test_env.lib_extension, "r")
            assert(fd:read("*a"):match(V"LuaFileSystem ${LUAFILESYSTEM_V}", 1, true))
            fd:close()
         end

         assert.is_true(run.luarocks_bool("remove luafilesystem ${LUAFILESYSTEM_V}"))
         assert.is.truthy(lfs.attributes(libdir.."/lfs."..test_env.lib_extension))

         if test_env.TEST_TARGET_OS ~= "windows" then
            local fd = io.open(libdir.."/lfs."..test_env.lib_extension, "r")
            assert(fd:read("*a"):match(V"LuaFileSystem ${LUAFILESYSTEM_OLD_V}", 1, true))
            fd:close()
         end
      end)
   end)

   it("#admin remove #ssh", function()
      assert.is_true(run.luarocks_admin_bool("--server=testing remove coxpcall-1.16.0-1.src.rock"))
   end)

   it("#admin remove missing", function()
      assert.is_false(run.luarocks_admin_bool("--server=testing remove"))
   end)
end)
