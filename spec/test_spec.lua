local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

local extra_rocks = {
   "/busted-2.2.0-1.src.rock",
   "/lua_cliargs-3.0-1.src.rock",
   "/luafilesystem-${LUAFILESYSTEM}.src.rock",
   "/luasystem-0.2.1-0.src.rock",
   "/dkjson-${DKJSON}.src.rock",
   "/say-1.4.1-3.src.rock",
   "/luassert-1.9.0-1.src.rock",
   "/penlight-1.13.1-1.src.rock",
   "/lua-term-0.8-1.rockspec",
   "/mediator_lua-1.1.2-0.rockspec",
}

describe("luarocks test #integration", function()

   lazy_setup(function()
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

      it("prepare", function()
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

         run.luarocks_bool("remove busted")
         local prepareOutput = run.luarocks_bool("test --prepare")
         assert.is_true(run.luarocks_bool("show busted"))

         -- Assert that "test --prepare" run successfully
         assert.is_true(prepareOutput)

         local output = run.luarocks("test")
         assert.not_match(tostring(prepareOutput), output)

      end)
   end)

   describe("command backend", function()
      describe("prepare", function()
         it("works with non-busted rocks", function()
            write_file("test.lua", "", finally)
            assert.is_true(run.luarocks_bool("test --prepare " .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec"))
         end)
      end)
   end)
end)

