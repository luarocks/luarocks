local test_env = require("test/test_environment")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/lxsh-0.8.6-2.src.rock",
   "/lxsh-0.8.6-2.rockspec",
   "/luasocket-3.0rc1-2.src.rock",
   "/luasocket-3.0rc1-2.rockspec",
   "/lpeg-1.0.0-1.src.rock",
}

describe("LuaRocks deps tests #blackbox #b_deps", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("LuaRocks deps mode one", function()
      assert.is_true(run.luarocks_bool("build --tree=system lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=one --tree=" .. testing_paths.testing_tree .. " lxsh"))
      
      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)

   it("LuaRocks deps mode order", function()
      assert.is_true(run.luarocks_bool("build --tree=system lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=order --tree=" .. testing_paths.testing_tree .. " lxsh"))

      assert.is.falsy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)

   it("LuaRocks deps mode order sys", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=order --tree=" .. testing_paths.testing_sys_tree .. " lxsh"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)

   it("LuaRocks deps mode all sys", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=all --tree=" .. testing_paths.testing_sys_tree .. " lxsh"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)

   it("LuaRocks deps mode none", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("build --deps-mode=none lxsh"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)

   it("LuaRocks nodeps alias", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " --nodeps lxsh"))

      assert.is.falsy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)

   it("LuaRocks deps mode make order", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_sys_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("download --source lxsh 0.8.6"))
      assert.is_true(run.luarocks_bool("unpack lxsh-0.8.6-2.src.rock"))
      lfs.chdir("lxsh-0.8.6-2/lxsh-0.8.6-1/")
      assert.is_true(run.luarocks_bool("make --tree=" .. testing_paths.testing_tree .. " --deps-mode=order"))

      lfs.chdir(testing_paths.luarocks_dir)
      test_env.remove_dir("lxsh-0.8.6-2")
      assert.is_true(os.remove("lxsh-0.8.6-2.src.rock"))

      assert.is.falsy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)
   
   it("LuaRocks deps mode make order sys", function()
      assert.is_true(run.luarocks_bool("build --tree=" .. testing_paths.testing_tree .. " lpeg"))
      assert.is_true(run.luarocks_bool("download --source lxsh 0.8.6"))
      assert.is_true(run.luarocks_bool("unpack lxsh-0.8.6-2.src.rock"))
      lfs.chdir("lxsh-0.8.6-2/lxsh-0.8.6-1/")
      assert.is_true(run.luarocks_bool("make --tree=" .. testing_paths.testing_sys_tree .. " --deps-mode=order"))

      lfs.chdir(testing_paths.luarocks_dir)
      test_env.remove_dir("lxsh-0.8.6-2")
      assert.is_true(os.remove("lxsh-0.8.6-2.src.rock"))

      assert.is.truthy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lpeg/1.0.0-1/lpeg-1.0.0-1.rockspec"))
      assert.is.falsy(lfs.attributes(testing_paths.testing_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh/0.8.6-2/lxsh-0.8.6-2.rockspec"))
   end)
end)
