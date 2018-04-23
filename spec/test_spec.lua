local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/busted-2.0.rc12-1.rockspec",
   "/lua_cliargs-3.0-1.src.rock",
   "/luafilesystem-1.7.0-2.src.rock",
   "/luasystem-0.2.1-0.src.rock",
   "/dkjson-2.5-2.src.rock",
   "/say-1.3-1.rockspec",
   "/luassert-1.7.9-0.rockspec",
   "/lua-term-0.7-1.rockspec",
   "/penlight-1.5.4-1.rockspec",
   "/mediator_lua-1.1.2-0.rockspec",   
}

describe("luarocks test #blackbox #b_test", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("fails with no flags/arguments", function()
      finally(function()
         lfs.chdir(testing_paths.testrun_dir)
         test_env.remove_dir("empty")
      end)
      assert(lfs.mkdir("empty"))
      assert(lfs.chdir("empty"))
      assert.is_false(run.luarocks_bool("test"))
   end)

   describe("busted backend", function()
      it("with rockspec, installing busted", function()
         finally(function()
            -- delete downloaded and unpacked files
            lfs.chdir(testing_paths.testrun_dir)
            test_env.remove_dir("luassert-1.7.9-0")
            os.remove("luassert-1.7.9-0.rockspec")
         end)
   
         -- make luassert
         assert.is_true(run.luarocks_bool("download --rockspec luassert 1.7.9-0"))
         assert.is_true(run.luarocks_bool("unpack luassert-1.7.9-0.rockspec"))
         lfs.chdir("luassert-1.7.9-0/luassert-1.7.9/")
         assert.is_true(run.luarocks_bool("make"))
         local output = run.luarocks("test --test-type=busted luassert-1.7.9-0.rockspec")
         -- Assert that busted ran, whether successfully or not
         assert.match("%d+ success.* / %d+ failure.* / %d+ error.* / %d+ pending", output)
      end)
   end)
end)
