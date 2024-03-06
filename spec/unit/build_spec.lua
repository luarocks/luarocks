local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local get_tmp_path = test_env.get_tmp_path
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file
local P = test_env.P

test_env.setup_specs()
local cfg = require("luarocks.core.cfg")
local deps = require("luarocks.deps")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local rockspecs = require("luarocks.rockspecs")
local build_builtin = require("luarocks.build.builtin")

local c_module_source = [[
   #include <lua.h>
   #include <lauxlib.h>

   int luaopen_c_module(lua_State* L) {
     lua_newtable(L);
     lua_pushinteger(L, 1);
     lua_setfield(L, -2, "c_module");
     return 1;
   }
]]

describe("LuaRocks build #unit", function()
   local runner

   lazy_setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
      cfg.init()
      fs.init()
      deps.check_lua_incdir(cfg.variables)
      deps.check_lua_libdir(cfg.variables)
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

   describe("build.builtin", function()
      it("builtin auto installs files in lua subdir", function()
         test_env.run_in_tmp(function(tmpdir)
            lfs.mkdir("lua")
            write_file("lua_module-1.0-1.rockspec", [[
               package = "lua_module"
               version = "1.0-1"
               source = {
                  url = "http://example.com/lua_module"
               }
               build = {
                  type = "builtin",
                  modules = {}
               }
            ]], finally)
            write_file("lua/lua_module.lua", "return 123", finally)

            assert.is_true(run.luarocks_bool("build"))
            assert.match("[\\/]lua_module%.lua", run.luarocks("show lua_module"))
         end, finally)
      end)

      describe("builtin.autodetect_modules", function()
         local tmpdir
         local olddir

         before_each(function()
            tmpdir = get_tmp_path()
            olddir = lfs.currentdir()
            lfs.mkdir(tmpdir)
            lfs.chdir(tmpdir)
            fs.change_dir(tmpdir)
         end)

         after_each(function()
            if olddir then
               lfs.chdir(olddir)
               fs.change_dir(olddir)
               if tmpdir then
                  lfs.rmdir(tmpdir)
               end
            end
         end)

         local libs = { "foo1", "foo2" }
         local incdirs = { "$(FOO1_INCDIR)", "$(FOO2_INCDIR)" }
         local libdirs = { "$(FOO1_LIBDIR)", "$(FOO2_LIBDIR)" }

         it("returns a table of the modules having as location the current directory", function()
            write_file("module1.lua", "", finally)
            write_file("module2.c", "", finally)
            write_file("module3.c", "int luaopen_my_module()", finally)
            write_file("test.lua", "", finally)
            write_file("tests.lua", "", finally)

            local modules = build_builtin.autodetect_modules(libs, incdirs, libdirs)
            assert.same(modules, {
               module1 = "module1.lua",
               module2 = {
                  sources = "module2.c",
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               },
               my_module = {
                  sources = "module3.c",
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               }
            })
         end)

         local test_with_location = function(location)
            lfs.mkdir(location)
            lfs.mkdir(location .. "/dir1")
            lfs.mkdir(location .. "/dir1/dir2")

            write_file(location .. "/module1.lua", "", finally)
            write_file(location .. "/dir1/module2.c", "", finally)
            write_file(location .. "/dir1/dir2/module3.c", "int luaopen_my_module()", finally)
            write_file(location .. "/test.lua", "", finally)
            write_file(location .. "/tests.lua", "", finally)

            local modules = build_builtin.autodetect_modules(libs, incdirs, libdirs)
            assert.same(modules, {
               module1 = P(location .. "/module1.lua"),
               ["dir1.module2"] = {
                  sources = P(location .. "/dir1/module2.c"),
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               },
               my_module = {
                  sources = P(location .. "/dir1/dir2/module3.c"),
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               }
            })

            lfs.rmdir(location .. "/dir1/dir2")
            lfs.rmdir(location .. "/dir1")
            lfs.rmdir(location)
         end

         it("returns a table of the modules having as location the src directory", function()
            test_with_location("src")
         end)

         it("returns a table of the modules having as location the lua directory", function()
            test_with_location("lua")
         end)

         it("returns as second and third argument tables of the bin files and copy directories", function()
            lfs.mkdir("doc")
            lfs.mkdir("docs")
            lfs.mkdir("samples")
            lfs.mkdir("tests")
            lfs.mkdir("bin")
            write_file("bin/binfile", "", finally)

            local _, install, copy_directories = build_builtin.autodetect_modules({}, {}, {})
            assert.same(install, { bin = { P"bin/binfile" } })
            assert.same(copy_directories, { "doc", "docs", "samples", "tests" })

            lfs.rmdir("doc")
            lfs.rmdir("docs")
            lfs.rmdir("samples")
            lfs.rmdir("tests")
            lfs.rmdir("bin")
         end)
      end)

      describe("builtin.run", function()
         local tmpdir
         local olddir

         before_each(function()
            tmpdir = get_tmp_path()
            olddir = lfs.currentdir()
            lfs.mkdir(tmpdir)
            lfs.chdir(tmpdir)
            fs.change_dir(tmpdir)
            path.use_tree(lfs.currentdir())
         end)

         after_each(function()
            if olddir then
               lfs.chdir(olddir)
               fs.change_dir(olddir)
               if tmpdir then
                  lfs.rmdir(tmpdir)
               end
            end
         end)

         it("returns false if the rockspec has no build modules and its format does not support autoextraction", function()
            local rockspec = {
               package = "test",
               version = "1.0-1",
               source = {
                  url = "http://example.com/test"
               },
               build = {}
            }

            rockspecs.from_persisted_table("test-1.0-1.rockspec", rockspec)
            assert.falsy(build_builtin.run(rockspec))
            rockspec.rockspec_format = "1.0"
            assert.falsy(build_builtin.run(rockspec))
         end)

         it("returns false if lua.h could not be found", function()
            local rockspec = {
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               build = {
                  type = "builtin",
                  modules = {
                     c_module = "c_module.c"
                  }
               }
            }
            write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            rockspec.variables = { LUA_INCDIR = "invalid" }
            assert.falsy(build_builtin.run(rockspec))
         end)

         it("returns false if the build fails", function()
            local rockspec = {
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               build = {
                  type = "builtin",
                  modules = {
                     c_module = "c_module.c"
                  }
               }
            }
            write_file("c_module.c", c_module_source .. "invalid", finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            assert.falsy(build_builtin.run(rockspec))
         end)

         it("returns true if the build succeeds with C module", function()
            local rockspec = {
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               build = {
                  type = "builtin",
                  modules = {
                     c_module = "c_module.c"
                  }
               }
            }
            write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            assert.truthy(build_builtin.run(rockspec))
            assert.truthy(lfs.attributes("lib/luarocks/rocks-" .. test_env.lua_version .. "/c_module/1.0-1/lib/c_module." .. test_env.lib_extension))
         end)

         it("returns true if the build succeeds with Lua module", function()
            local rockspec = {
               rockspec_format = "1.0",
               package = "test",
               version = "1.0-1",
               source = {
                  url = "http://example.com/test"
               },
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            }
            write_file("test.lua", "return {}", finally)

            rockspecs.from_persisted_table("test-1.0-1.rockspec", rockspec)
            assert.truthy(build_builtin.run(rockspec))
            assert.truthy(lfs.attributes("lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/lua/test.lua"))
         end)

         it("automatically extracts the modules and libraries if they are not given and builds against any external dependencies", function()
            local fdir = testing_paths.fixtures_dir
            if test_env.TEST_TARGET_OS == "windows" then
               if test_env.MINGW then
                  os.execute("gcc -shared -o " .. fdir .. "/libfixturedep.dll -Wl,--out-implib," .. fdir .."/libfixturedep.a " .. fdir .. "/fixturedep.c")
               else
                  os.execute("cl " .. fdir .. "\\fixturedep.c /link /export:fixturedep_fn /out:" .. fdir .. "\\fixturedep.dll /implib:" .. fdir .. "\\fixturedep.lib")
               end
            elseif test_env.TEST_TARGET_OS == "linux" then
               os.execute("gcc -shared -o " .. fdir .. "/libfixturedep.so " .. fdir .. "/fixturedep.c")
            elseif test_env.TEST_TARGET_OS == "osx" then
               os.execute("cc -dynamiclib -o " .. fdir .. "/libfixturedep.dylib " .. fdir .. "/fixturedep.c")
            end

            local rockspec = {
               rockspec_format = "3.0",
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               external_dependencies = {
                  FIXTUREDEP = {
                     library = "fixturedep"
                  }
               },
               build = {
                  type = "builtin"
               }
            }
            write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            rockspec.variables["FIXTUREDEP_LIBDIR"] = testing_paths.fixtures_dir
            assert.truthy(build_builtin.run(rockspec))
         end)

         it("returns false if any external dependency is missing", function()
            local rockspec = {
               rockspec_format = "3.0",
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "https://example.com/c_module"
               },
               external_dependencies = {
                  EXTDEP = {
                    library = "missing"
                  }
               },
               build = {
                  type = "builtin"
               }
            }
            write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            rockspec.variables["EXTDEP_INCDIR"] = lfs.currentdir()
            rockspec.variables["EXTDEP_LIBDIR"] = lfs.currentdir()
            assert.falsy(build_builtin.run(rockspec))
         end)
      end)
   end)
end)
