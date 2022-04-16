local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local get_tmp_path = test_env.get_tmp_path
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file
local git_repo = require("spec.util.git_repo")

test_env.unload_luarocks()
local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")

local extra_rocks = {
   "/lmathx-20120430.51-1.src.rock",
   "/lmathx-20120430.51-1.rockspec",
   "/lmathx-20120430.52-1.src.rock",
   "/lmathx-20120430.52-1.rockspec",
   "/lmathx-20150505-1.src.rock",
   "/lmathx-20150505-1.rockspec",
   "/lpeg-1.0.0-1.rockspec",
   "/lpeg-1.0.0-1.src.rock",
   "/luafilesystem-${LUAFILESYSTEM}.src.rock",
   "/luasocket-${LUASOCKET}.src.rock",
   "/luasocket-${LUASOCKET}.rockspec",
   "spec/fixtures/a_rock-1.0-1.src.rock",
   "/busted-2.0.0-1.rockspec",
   "/busted-2.0.rc13-0.rockspec",
}

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

describe("LuaRocks build #integration", function()
   lazy_setup(function()
      cfg.init()
      fs.init()
   end)

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("basic testing set", function()
      it("invalid", function()
         assert.is_false(run.luarocks_bool("build invalid"))
      end)

      it("with no arguments behaves as luarocks make", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("c_module-1.0-1.rockspec", [[
               package = "c_module"
               version = "1.0-1"
               source = {
                  url = "http://example.com/c_module"
               }
               build = {
                  type = "builtin",
                  modules = {
                     c_module = { "c_module.c" }
                  }
               }
            ]], finally)
            write_file("c_module.c", c_module_source, finally)

            assert.is_true(run.luarocks_bool("build"))
            assert.truthy(lfs.attributes(tmpdir .. "/c_module." .. test_env.lib_extension))
         end, finally)
      end)
   end)

   describe("building with flags", function()
      it("fails if it doesn't have the permissions to access the specified tree #unix", function()
         assert.is_false(run.luarocks_bool("build --tree=/usr " .. testing_paths.fixtures_dir .. "/a_rock-1.0.1-rockspec"))
         assert.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("fails if it doesn't have the permissions to access the specified tree's parent #unix", function()
         assert.is_false(run.luarocks_bool("build --tree=/usr/invalid " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec"))
         assert.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("verbose", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build --verbose test-1.0-1.rockspec"))
            assert.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/test/1.0-1/test-1.0-1.rockspec"))
         end, finally)
      end)

      it("fails if the deps-mode argument is invalid", function()
         assert.is_false(run.luarocks_bool("build --deps-mode=123 " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec"))
         assert.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("with --only-sources", function()
         assert.is_true(run.luarocks_bool("download --server=" .. testing_paths.fixtures_dir .. "/a_repo --rockspec a_rock 1.0"))
         assert.is_false(run.luarocks_bool("build --only-sources=\"http://example.com\" a_rock-1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))

         assert.is_true(run.luarocks_bool("download --server=" .. testing_paths.fixtures_dir .. "/a_repo --source a_rock 1.0"))
         assert.is_true(run.luarocks_bool("build --only-sources=\"http://example.com\" a_rock-1.0-1.src.rock"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))

         assert.is_true(os.remove("a_rock-1.0-1.rockspec"))
         assert.is_true(os.remove("a_rock-1.0-1.src.rock"))
      end)

      it("fails if an empty tree is given", function()
         assert.is_false(run.luarocks_bool("build --tree=\"\" " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec"))
         assert.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)
   end)

   describe("basic builds", function()
      it("luacov diff version", function()
         assert.is_true(run.luarocks_bool("build luacov ${LUACOV}"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/luacov/${LUACOV}/luacov-${LUACOV}.rockspec"))
      end)

      it("fails if the current platform is not supported", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               supported_platforms = {
                  "unix", "macosx"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            write_file("test.lua", "return {}", finally)

            if test_env.TEST_TARGET_OS == "windows" then
               assert.is_false(run.luarocks_bool("build test-1.0-1.rockspec")) -- Error: This rockspec does not support windows platforms
               assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/test/1.0-1/test-1.0-1.rockspec"))
            else
               assert.is_true(run.luarocks_bool("build test-1.0-1.rockspec"))
               assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/test/1.0-1/test-1.0-1.rockspec"))
            end
         end, finally)
      end)

      it("with skipping dependency checks", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock 1.0"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build test-1.0-1.rockspec --deps-mode=none"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/test/1.0-1/test-1.0-1.rockspec"))
         end)
      end)

      it("supports --pin #pinning", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock >= 0.8"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build --server=" .. testing_paths.fixtures_dir .. "/a_repo test-1.0-1.rockspec --pin --tree=lua_modules"))
            assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/2.0-1/a_rock-2.0-1.rockspec"))
            local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/luarocks.lock"
            assert.is.truthy(lfs.attributes(lockfilename))
            local lockdata = loadfile(lockfilename)()
            assert.same({
               dependencies = {
                  ["a_rock"] = "2.0-1",
                  ["lua"] = test_env.lua_version .. "-1",
               }
            }, lockdata)
         end)
      end)

      it("supports --pin --only-deps #pinning", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock >= 0.8"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build --server=" .. testing_paths.fixtures_dir .. "/a_repo test-1.0-1.rockspec --pin --only-deps --tree=lua_modules"))
            assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/2.0-1/a_rock-2.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("./luarocks.lock"))
            local lockfilename = "./luarocks.lock"
            assert.is.truthy(lfs.attributes(lockfilename))
            local lockdata = loadfile(lockfilename)()
            assert.same({
               dependencies = {
                  ["a_rock"] = "2.0-1",
                  ["lua"] = test_env.lua_version .. "-1",
               }
            }, lockdata)
         end)
      end)

      it("lmathx deps partial match", function()
         if test_env.LUA_V == "5.1" or test_env.LUAJIT_V then
            assert.is_true(run.luarocks_bool("build lmathx"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lmathx/20120430.51-1/lmathx-20120430.51-1.rockspec"))
         elseif test_env.LUA_V == "5.2" then
            assert.is_true(run.luarocks_bool("build lmathx"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lmathx/20120430.52-1/lmathx-20120430.52-1.rockspec"))
         elseif test_env.LUA_V == "5.3" then
            assert.is_true(run.luarocks_bool("build lmathx"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lmathx/20150505-1/lmathx-20150505-1.rockspec"))
         end
      end)
   end)

   describe("#namespaces", function()
      it("builds a namespaced package from the command-line", function()
         assert(run.luarocks_bool("build a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/2.0-1/rock_namespace"))
      end)

      it("builds a package with a namespaced dependency", function()
         assert(run.luarocks_bool("build has_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show has_namespaced_dep"))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
      end)

      it("builds a package reusing a namespaced dependency", function()
         assert(run.luarocks_bool("build a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("build has_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" )
         assert.has.no.match("Missing dependencies", output)
      end)

      it("builds a package considering namespace of locally installed package", function()
         assert(run.luarocks_bool("build a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("build has_another_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" )
         assert.has.match("Missing dependencies", output)
         print(output)
         assert(run.luarocks_bool("show a_rock 3.0"))
      end)
   end)

   describe("more complex tests", function()
      if test_env.TYPE_TEST_ENV == "full" then
         it("luacheck show downloads test_config", function()
            local output = run.luarocks("build luacheck", { LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/testing_config_show_downloads.lua"} )
            assert.is.truthy(output:match("%.%.%."))
         end)
      end

      it("downgrades directories correctly", function()
         assert(run.luarocks_bool("build --nodeps busted 2.0.0" ))
         assert(run.luarocks_bool("build --nodeps busted 2.0.rc13" ))
         assert(run.luarocks_bool("build --nodeps busted 2.0.0" ))
      end)

      it("only deps", function()
         local rockspec = testing_paths.fixtures_dir .. "/build_only_deps-0.1-1.rockspec"

         assert.is_true(run.luarocks_bool("build " .. rockspec .. " --only-deps"))
         assert.is_false(run.luarocks_bool("show build_only_deps"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/build_only_deps/0.1-1/build_only_deps-0.1-1.rockspec"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("only deps of a given rockspec", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock 1.0"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            write_file("test.lua", "return {}", finally)

            assert.is.truthy(run.luarocks_bool("build --server=" .. testing_paths.fixtures_dir .. "/a_repo test-1.0-1.rockspec --only-deps"))
            assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         end, finally)
      end)

      it("only deps of a given rock", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock 1.0"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            write_file("test.lua", "return {}", finally)

            assert.is.truthy(run.luarocks_bool("pack test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("test-1.0-1.src.rock"))

            assert.is.truthy(run.luarocks_bool("build --server=" .. testing_paths.fixtures_dir .. "/a_repo test-1.0-1.src.rock --only-deps"))
            assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         end, finally)
      end)

      it("fails if given an argument with an invalid patch", function()
         assert.is_false(run.luarocks_bool("build " .. testing_paths.fixtures_dir .. "/invalid_patch-0.1-1.rockspec"))
      end)
   end)

   describe("rockspec format 3.0 #rs3", function()
      local tmpdir
      local olddir

      before_each(function()
         tmpdir = get_tmp_path()
         olddir = lfs.currentdir()
         lfs.mkdir(tmpdir)
         lfs.chdir(tmpdir)

         lfs.mkdir("autodetect")
         write_file("autodetect/bla.lua", "return {}", finally)
         write_file("c_module.c", c_module_source, finally)
      end)

      after_each(function()
         if olddir then
            lfs.chdir(olddir)
            if tmpdir then
               lfs.rmdir("autodetect")
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("defaults to build.type == 'builtin'", function()
         local rockspec = "a_rock-1.0-1.rockspec"
         test_env.write_file(rockspec, [[
            rockspec_format = "3.0"
            package = "a_rock"
            version = "1.0-1"
            source = {
               url = "file://]] .. testing_paths.fixtures_dir .. [[/a_rock.lua"
            }
            description = {
               summary = "An example rockspec",
            }
            dependencies = {
               "lua >= 5.1"
            }
            build = {
               modules = {
                  build = "a_rock.lua"
               },
            }
         ]], finally)
         assert.truthy(run.luarocks_bool("build " .. rockspec))
         assert.is.truthy(run.luarocks("show a_rock"))
      end)

      it("'builtin' detects lua files if build is not given", function()
         local rockspec = "autodetect-1.0-1.rockspec"
         test_env.write_file(rockspec, [[
            rockspec_format = "3.0"
            package = "autodetect"
            version = "1.0-1"
            source = {
               url = "file://autodetect/bla.lua"
            }
            description = {
               summary = "An example rockspec",
            }
            dependencies = {
               "lua >= 5.1"
            }
         ]], finally)
         assert.truthy(run.luarocks_bool("build " .. rockspec))
         assert.match("bla.lua", run.luarocks("show autodetect"))
      end)

      it("'builtin' synthesizes external_dependencies if not given but a library is given in build", function()
         local rockspec = "autodetect-1.0-1.rockspec"
         test_env.write_file(rockspec, [[
            rockspec_format = "3.0"
            package = "autodetect"
            version = "1.0-1"
            source = {
               url = "file://c_module.c"
            }
            description = {
               summary = "An example rockspec",
            }
            dependencies = {
               "lua >= 5.1"
            }
            build = {
               modules = {
                  c_module = {
                     sources = "c_module.c",
                     libraries = "inexistent_library",
                  }
               }
            }
         ]], finally)
         assert.match("INEXISTENT_LIBRARY_DIR", run.luarocks("build " .. rockspec))
      end)
   end)

   describe("#mock external dependencies", function()
      lazy_setup(function()
         test_env.mock_server_init()
      end)

      lazy_teardown(function()
         test_env.mock_server_done()
      end)

      it("fails when missing external dependency", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("missing_external-0.1-1.rockspec", [[
               package = "missing_external"
               version = "0.1-1"
               source = {
                  url = "https://example.com/build.lua"
               }
               external_dependencies = {
                  INEXISTENT = {
                     library = "inexistentlib*",
                     header = "inexistentheader*.h",
                  }
               }
               dependencies = {
                  "lua >= 5.1"
               }
               build = {
                  type = "builtin",
                  modules = {
                     build = "build.lua"
                  }
               }
            ]], finally)
            assert.is_false(run.luarocks_bool("build missing_external-0.1-1.rockspec INEXISTENT_INCDIR=\"/invalid/dir\""))
         end, finally)
      end)

      it("builds with external dependency", function()
         local rockspec = testing_paths.fixtures_dir .. "/with_external_dep-0.1-1.rockspec"
         local foo_incdir = testing_paths.fixtures_dir .. "/with_external_dep"
         assert.is_truthy(run.luarocks_bool("build " .. rockspec .. " FOO_INCDIR=\"" .. foo_incdir .. "\""))
         assert.is.truthy(run.luarocks("show with_external_dep"))
      end)
   end)

   describe("#build_dependencies", function()
      it("builds with a build dependency", function()
         assert(run.luarocks_bool("build has_build_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show has_build_dep 1.0"))
         assert(run.luarocks_bool("show a_build_dep 1.0"))
      end)
   end)

end)

test_env.unload_luarocks()
test_env.setup_specs()
local cfg = require("luarocks.core.cfg")
local deps = require("luarocks.deps")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local rockspecs = require("luarocks.rockspecs")
local build_builtin = require("luarocks.build.builtin")

describe("LuaRocks build #unit", function()
   local runner

   lazy_setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
      runner.tick = true
      cfg.init()
      fs.init()
      deps.check_lua_incdir(cfg.variables)
      deps.check_lua_libdir(cfg.variables)
   end)

   lazy_teardown(function()
      runner.shutdown()
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

      describe("builtin.autodetect_external_dependencies", function()
         it("returns false if the given build table has no external dependencies", function()
            local build_table = {
               type = "builtin"
            }

            assert.falsy(build_builtin.autodetect_external_dependencies(build_table))
         end)

         it("returns a table of the external dependencies found in the given build table", function()
            local build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = { "foo1", "foo2" },
                  },
                  module2 = {
                     libraries = "foo3"
                  },
               }
            }

            local extdeps = build_builtin.autodetect_external_dependencies(build_table)
            assert.same(extdeps["FOO1"], { library = "foo1" })
            assert.same(extdeps["FOO2"], { library = "foo2" })
            assert.same(extdeps["FOO3"], { library = "foo3" })
         end)

         it("adds proper include and library dirs to the given build table", function()
            local build_table

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo"
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "$(FOO_INCDIR)" },
                     libdirs = { "$(FOO_LIBDIR)" }
                  }
               }
            })

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" }
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" },
                     libdirs = { "$(FOO_LIBDIR)" }
                  }
               }
            })

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     libdirs = { "LIBDIRS" }
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "$(FOO_INCDIR)" },
                     libdirs = { "LIBDIRS" }
                  }
               }
            })

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" },
                     libdirs = { "LIBDIRS" }
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" },
                     libdirs = { "LIBDIRS" }
                  }
               }
            })
         end)
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
               module1 = location .. "/module1.lua",
               ["dir1.module2"] = {
                  sources = location .. "/dir1/module2.c",
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               },
               my_module = {
                  sources = location .. "/dir1/dir2/module3.c",
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
            assert.same(install, { bin = { "bin/binfile" } })
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

   describe("#unix build from #git", function()
      local git

      lazy_setup(function()
         git = git_repo.start()
      end)

      lazy_teardown(function()
         if git then
            git:stop()
         end
      end)

      it("using --branch", function()
         write_file("my_branch-1.0-1.rockspec", [[
            rockspec_format = "3.0"
            package = "my_branch"
            version = "1.0-1"
            source = {
               url = "git://localhost/testrock"
            }
         ]], finally)
         assert.is_false(run.luarocks_bool("build --branch unknown-branch ./my_branch-1.0-1.rockspec"))
         assert.is_true(run.luarocks_bool("build --branch test-branch ./my_branch-1.0-1.rockspec"))
      end)
   end)

end)

