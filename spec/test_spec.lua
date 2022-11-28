local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local get_tmp_path = test_env.get_tmp_path
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

test_env.unload_luarocks()

local extra_rocks = {
   "/busted-2.0.0-1.rockspec",
   "/lua_cliargs-3.0-1.src.rock",
   "/luafilesystem-${LUAFILESYSTEM}.src.rock",
   "/luasystem-0.2.1-0.src.rock",
   "/dkjson-${DKJSON}.src.rock",
   "/say-1.3-1.rockspec",
   "/luassert-1.8.0-0.rockspec",
   "/lua-term-0.7-1.rockspec",
   "/penlight-1.5.4-1.rockspec",
   "/mediator_lua-1.1.2-0.rockspec",
}

describe("luarocks test #integration", function()

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

      lazy_setup(function()
         -- Try to cache rocks from the host system to speed up test
         for _, r in ipairs(extra_rocks) do
            r = test_env.V(r)
            local n, v = r:match("^/(.*)%-([^%-]+)%-%d+%.[^%-]+$")
            os.execute("luarocks pack " .. n .. " " .. v)
         end
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

test_env.unload_luarocks()

local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")
local path = require("luarocks.path")
local test = require("luarocks.test")
local test_busted = require("luarocks.test.busted")
local test_command = require("luarocks.test.command")

describe("LuaRocks test #unit", function()
   local runner

   lazy_setup(function()
      cfg.init()
      fs.init()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
      runner.tick = true
   end)

   lazy_teardown(function()
      runner.shutdown()
   end)

   local tmpdir
   local olddir

   local create_tmp_dir = function()
      tmpdir = get_tmp_path()
      olddir = lfs.currentdir()
      lfs.mkdir(tmpdir)
      lfs.chdir(tmpdir)
      fs.change_dir(tmpdir)
   end

   local destroy_tmp_dir = function()
      if olddir then
         lfs.chdir(olddir)
         if tmpdir then
            lfs.rmdir(tmpdir)
         end
      end
   end

   describe("test.command", function()
      describe("command.detect_type", function()
         before_each(function()
            create_tmp_dir()
         end)

         after_each(function()
            destroy_tmp_dir()
         end)

         it("returns true if test.lua exists", function()
            write_file("test.lua", "", finally)
            assert.truthy(test_command.detect_type())
         end)

         it("returns false if test.lua doesn't exist", function()
            assert.falsy(test_command.detect_type())
         end)
      end)

      describe("command.run_tests", function()
         before_each(function()
            create_tmp_dir()
         end)

         after_each(function()
            destroy_tmp_dir()
         end)

         it("returns the result of the executed tests", function()
            write_file("test.lua", "assert(1==1)", finally)
            assert.truthy(test_command.run_tests(nil, {}))

            write_file("test.lua", "assert(1==2)", finally)
            assert.falsy(test_command.run_tests(nil, {}))
         end)

         it("returns the result of the executed tests with custom arguments and test command", function()
            write_file("test.lua", "assert(1==1)", finally)

            local test = {
               script = "test.lua",
               flags = {
                  arg1 = "1",
                  arg2 = "2"
               },
               command = fs.Q(testing_paths.lua)
            }
            assert.truthy(test_command.run_tests(test, {}))
         end)

         it("returns false and does nothing if the test script doesn't exist", function()
            assert.falsy(test_command.run_tests(nil, {}))
         end)
      end)
   end)

   describe("test.busted", function()
      describe("busted.detect_type", function()
         before_each(function()
            create_tmp_dir()
         end)

         after_each(function()
            destroy_tmp_dir()
         end)

         it("returns true if .busted exists", function()
            write_file(".busted", "", finally)
            assert.truthy(test_busted.detect_type())
         end)

         it("returns false if .busted doesn't exist", function()
            assert.falsy(test_busted.detect_type())
         end)
      end)

      describe("busted.run_tests", function()
         before_each(function()
            path.use_tree(testing_paths.testing_sys_tree)
            create_tmp_dir()
         end)

         after_each(function()
            destroy_tmp_dir()
         end)

         pending("returns the result of the executed tests", function()
            -- FIXME: busted issue
            write_file("test_spec.lua", "assert(1==1)", finally)
            assert.truthy(test_busted.run_tests(nil, {}))

            write_file("test_spec.lua", "assert(1==2)", finally)
            assert.falsy(test_busted.run_tests())
         end)
      end)
   end)

   describe("test", function()
      describe("test.run_test_suite", function()
         before_each(function()
            create_tmp_dir()
         end)

         after_each(function()
            destroy_tmp_dir()
         end)

         it("returns false if the given rockspec cannot be loaded", function()
            assert.falsy(test.run_test_suite("invalid", nil, {}))
         end)

         it("returns false if no test type was detected", function()
            assert.falsy(test.run_test_suite({ package = "test" }, nil, {}))
         end)

         it("returns the result of executing the tests specified in the given rockspec", function()
            write_file("test.lua", "assert(1==1)", finally)
            assert.truthy(test.run_test_suite({ test_dependencies = {} }, nil, {}))

            write_file("test.lua", "assert(1==2)", finally)
            assert.falsy(test.run_test_suite({ test_dependencies = {} }, nil, {}))
         end)
      end)
   end)
end)
