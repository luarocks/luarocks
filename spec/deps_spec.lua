local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

local extra_rocks = {
   "/lxsh-${LXSH}.src.rock",
   "/luasocket-${LUASOCKET}.src.rock",
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
