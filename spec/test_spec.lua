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
   "/luassert-1.7.10-0.rockspec",
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

      setup(function()
         -- Try to cache rocks from the host system to speed up test
         os.execute("luarocks pack busted")
         os.execute("luarocks pack lua_cliargs")
         os.execute("luarocks pack luafilesystem")
         os.execute("luarocks pack dkjson")
         os.execute("luarocks pack luasystem")
         os.execute("luarocks pack say")
         os.execute("luarocks pack luassert")
         os.execute("luarocks pack lua-term")
         os.execute("luarocks pack penlight")
         os.execute("luarocks pack mediator_lua")
         if test_env.TEST_TARGET_OS == "windows" then
            os.execute("move *.rock " .. testing_paths.testing_server)
         else
            os.execute("mv *.rock " .. testing_paths.testing_server)
         end
         test_env.run.luarocks_admin_nocov("make_manifest " .. testing_paths.testing_server)
      end)

      it("with rockspec, installing busted", function()
         finally(function()
            -- delete downloaded and unpacked files
            lfs.chdir(testing_paths.testrun_dir)
            test_env.remove_dir("busted_project-0.1-1")
            os.remove("busted_project-0.1-1.src.rock")
         end)
   
         -- make luassert
         assert.is_true(run.luarocks_bool("download --server="..testing_paths.fixtures_repo_dir.." busted_project 0.1-1"))
         assert.is_true(run.luarocks_bool("unpack busted_project-0.1-1.src.rock"))
         lfs.chdir("busted_project-0.1-1/busted_project")
         assert.is_true(run.luarocks_bool("make"))
         local output = run.luarocks("test")
         print(output)
         -- Assert that busted ran, whether successfully or not
         assert.match("%d+ success.* / %d+ failure.* / %d+ error.* / %d+ pending", output)
      end)
   end)
end)
