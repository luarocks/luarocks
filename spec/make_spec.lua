local test_env = require("test/test_environment")
local lfs = require("lfs")

test_env.unload_luarocks()

local extra_rocks = {
   "/lpeg-0.12-1.src.rock",
   "/luasocket-3.0rc1-1.src.rock",
   "/luasocket-3.0rc1-1.rockspec",
   "/lxsh-0.8.6-2.src.rock",
   "/lxsh-0.8.6-2.rockspec"
}

expose("LuaRocks make tests #blackbox #b_make", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
      run = test_env.run
      testing_paths = test_env.testing_paths
   end)

   it("LuaRocks make with no flags/arguments", function()
      lfs.chdir("test")
      assert.is_false(run.luarocks_bool("make"))
      lfs.chdir(testing_paths.luarocks_dir)
   end)

   it("LuaRocks make with rockspec", function()
      -- make luasocket
      assert.is_true(run.luarocks_bool("download --source luasocket"))
      assert.is_true(run.luarocks_bool("unpack luasocket-3.0rc1-1.src.rock"))
      lfs.chdir("luasocket-3.0rc1-1/luasocket-3.0-rc1/")
      assert.is_true(run.luarocks_bool("make luasocket-3.0rc1-1.rockspec"))

      -- test it
      assert.is_true(run.luarocks_bool("show luasocket"))
      assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/luasocket"))

      -- delete downloaded and unpacked files
      lfs.chdir(testing_paths.luarocks_dir)
      test_env.remove_dir("luasocket-3.0rc1-1")
      assert.is_true(os.remove("luasocket-3.0rc1-1.src.rock"))
   end)

   describe("LuaRocks making rockspecs (using lxsh)", function()
      --download lxsh and unpack it
      before_each(function()
         assert.is_true(run.luarocks_bool("download --source lxsh 0.8.6-2"))
         assert.is_true(run.luarocks_bool("unpack lxsh-0.8.6-2.src.rock"))
         assert.is_true(lfs.chdir("lxsh-0.8.6-2/lxsh-0.8.6-1/"))
      end)
   
      -- delete downloaded and unpacked files
      after_each(function()
         assert.is_true(lfs.chdir(testing_paths.luarocks_dir))
         test_env.remove_dir("lxsh-0.8.6-2")
         assert.is_true(os.remove("lxsh-0.8.6-2.src.rock"))
      end)         

      it("LuaRocks make default rockspec", function()
         assert.is_true(run.luarocks_bool("new_version lxsh-0.8.6-2.rockspec"))
         assert.is_true(run.luarocks_bool("make"))

         assert.is_true(run.luarocks_bool("show lxsh"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh"))
      end)

      it("LuaRocks make unnamed rockspec", function()
         os.execute("cp lxsh-0.8.6-2.rockspec rockspec") --rewrite with lfs
         assert.is_true(run.luarocks_bool("make"))

         assert.is_true(run.luarocks_bool("show lxsh"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh"))
      end)
      
      it("LuaRocks make ambiguous rockspec", function()
         assert.is.truthy(os.rename("lxsh-0.8.6-2.rockspec", "lxsh2-0.8.6-2.rockspec"))
         assert.is_false(run.luarocks_bool("make"))

         assert.is_false(run.luarocks_bool("show lxsh"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh"))
      end)
      
      it("LuaRocks make ambiguous unnamed rockspec", function()
         assert.is.truthy(os.rename("lxsh-0.8.6-2.rockspec", "1_rockspec"))
         os.execute("cp 1_rockspec 2_rockspec") --rewrite with lfs
         assert.is_false(run.luarocks_bool("make"))

         assert.is_false(run.luarocks_bool("show lxsh"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/luarocks/rocks/lxsh"))
      end)
      
      it("LuaRocks make pack binary rock", function()
         assert.is_true(run.luarocks_bool("make --deps-mode=none --pack-binary-rock"))
         assert.is.truthy(lfs.attributes("lxsh-0.8.6-2.all.rock"))
      end)
   end)
end)
