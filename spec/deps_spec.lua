local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/lxsh-${LXSH}.src.rock",
   "/lxsh-${LXSH}.rockspec",
   "/luasocket-${LUASOCKET}.src.rock",
   "/luasocket-${LUASOCKET}.rockspec",
   "/lpeg-${LPEG}.src.rock",
}

describe("LuaRocks deps-mode #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("one", function()
      assert.is_true(run.luarocks_bool("build --tree=system lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=one --tree=" .. testing_paths.testing_tree .. " lxsh"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)

   it("order", function()
      assert.is_true(run.luarocks_bool("build --tree=system lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=order --tree=" .. testing_paths.testing_tree .. " lxsh"))

      assert.is.falsy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)

   it("order sys", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=order --tree=" .. testing_paths.testing_sys_tree .. " lxsh"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)

   it("all sys", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=all --tree=" .. testing_paths.testing_sys_tree .. " lxsh"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)

   it("none", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=none lxsh"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)

   it("LuaRocks nodeps alias", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " --nodeps lxsh"))

      assert.is.falsy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)

   it("make order", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_sys_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("download --source lxsh ${LXSH_V}"))
      assert.is_true(run.luarocks_bool("unpack lxsh-${LXSH}.src.rock"))
      lfs.chdir("lxsh-${LXSH}/lxsh-${LXSH_V}-1/")
      assert.is_true(run.luarocks_bool("make --tree=" .. testing_paths.testing_tree .. " --deps-mode=order"))

      finally(function()
         lfs.chdir(testing_paths.testrun_dir)
         test_env.remove_dir("lxsh-${LXSH}")
         assert.is_true(os.remove("lxsh-${LXSH}.src.rock"))
      end)

      assert.is.falsy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)

   it("make order sys", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("download --source lxsh ${LXSH_V}"))
      assert.is_true(run.luarocks_bool("unpack lxsh-${LXSH}.src.rock"))
      lfs.chdir("lxsh-${LXSH}/lxsh-${LXSH_V}-1/")
      assert.is_true(run.luarocks_bool("make --tree=" .. testing_paths.testing_sys_tree .. " --deps-mode=order"))

      finally(function()
         lfs.chdir(testing_paths.testrun_dir)
         test_env.remove_dir("lxsh-${LXSH}")
         assert.is_true(os.remove("lxsh-${LXSH}.src.rock"))
      end)

      assert.is.truthy(lfs.attributes(testing_paths.testing_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lpeg/${LPEG}/lpeg-${LPEG}.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/lxsh/${LXSH}/lxsh-${LXSH}.rockspec"))
   end)
end)

test_env.unload_luarocks()
test_env.setup_specs()
local cfg = require("luarocks.core.cfg")
local deps = require("luarocks.deps")
local fs = require("luarocks.fs")

describe("LuaRocks deps #unit", function()
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

   describe("deps", function()
      describe("deps.autodetect_external_dependencies", function()
         it("returns false if the given build table has no external dependencies", function()
            local build_table = {
               type = "builtin"
            }

            assert.falsy(deps.autodetect_external_dependencies(build_table))
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

            local extdeps = deps.autodetect_external_dependencies(build_table)
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
            deps.autodetect_external_dependencies(build_table)
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
            deps.autodetect_external_dependencies(build_table)
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
            deps.autodetect_external_dependencies(build_table)
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
            deps.autodetect_external_dependencies(build_table)
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
   end)
end)
