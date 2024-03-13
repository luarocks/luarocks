local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local get_tmp_path = test_env.get_tmp_path
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file
local git_repo = require("spec.util.git_repo")

local cfg, fs

local extra_rocks = {
   "/lmathx-20120430.51-1.src.rock",
   "/lmathx-20120430.51-1.rockspec",
   "/lmathx-20120430.52-1.src.rock",
   "/lmathx-20120430.52-1.rockspec",
   "/lmathx-20150505-1.src.rock",
   "/lmathx-20150505-1.rockspec",
   "/lpeg-1.0.0-1.src.rock",
   "/luafilesystem-${LUAFILESYSTEM}.src.rock",
   "/luasocket-${LUASOCKET}.src.rock",
   "spec/fixtures/a_rock-1.0-1.src.rock",
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
   before_each(function()
      test_env.setup_specs(extra_rocks)
      cfg = require("luarocks.core.cfg")
      fs = require("luarocks.fs")
      cfg.init()
      fs.init()
   end)

   describe("building with flags", function()
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
            ]])
            write_file("test.lua", "return {}")

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
            ]])
            write_file("test.lua", "return {}")

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
            ]])
            write_file("test.lua", "return {}")

            assert.is_true(run.luarocks_bool("build test-1.0-1.rockspec --deps-mode=none"))
            assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/test/1.0-1/test-1.0-1.rockspec"))
         end, finally)
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
            ]])
            write_file("test.lua", "return {}")

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
            ]])
            write_file("test.lua", "return {}")

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
               url = "file://]] .. testing_paths.fixtures_dir:gsub("\\", "/") .. [[/a_rock.lua"
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
         test_env.setup_specs(nil, "mock")
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
            ]])
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
