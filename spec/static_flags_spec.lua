local test_env = require("test/test_environment")
local testing_paths = test_env.testing_paths
local lfs = require("lfs")
local run = test_env.run

test_env.unload_luarocks()

local extra_rocks = {
   "/luasocket-3.0rc1-2.src.rock",
   "/luasocket-3.0rc1-2.rockspec"
}

describe("LuaRocks add tests #blackbox #b_static_flags #unix", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("LuaRocks static_flags basic tests #unix", function()
      it("LuaRocks static_flags for luasocket", function()
         assert.is_true(run.luarocks_bool("download luasocket"))
         assert.is_true(run.luarocks_bool("unpack luasocket-3.0rc1-2.src.rock"))
         lfs.chdir("luasocket-3.0rc1-2/luasocket-3.0-rc1/")
         assert.is_true(run.luarocks_bool("make --static luasocket-3.0rc1-2.rockspec " .. test_env.OPENSSL_DIRS))
         lfs.chdir(testing_paths.luarocks_dir)
         local output = run.luarocks("static_flags luasocket")
         assert.is.truthy(output:match("luarocks%-core%.a"))
         assert.is.truthy(output:match("luarocks%-unix%.a"))
         assert.is.truthy(output:match("luarocks%-serial%.a"))
         test_env.remove_dir("luasocket-3.0rc1-2")
      end)
   end)
end)
