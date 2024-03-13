local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

describe("luarocks pack #integration", function()

   lazy_setup(function()
      test_env.setup_specs()
   end)

   describe("#mock", function()

      lazy_setup(function()
         test_env.setup_specs(extra_rocks, "mock")
         test_env.mock_server_init()
      end)

      lazy_teardown(function()
         test_env.mock_server_done()
      end)

      it("can pack a rockspec into a .src.rock", function()
         finally(function()
            os.remove("a_rock-1.0-1.src.rock")
         end)
         assert(run.luarocks_bool("download --rockspec --server=" .. testing_paths.fixtures_dir .. "/a_repo a_rock 1.0-1"))
         assert(run.luarocks_bool("pack a_rock-1.0-1.rockspec"))
         assert.is_truthy(lfs.attributes("a_rock-1.0-1.src.rock"))
      end)

      it("can pack a rockspec with a bare file:// in the url", function()
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
            ]], finally)
            write_file("test.lua", "return {}", finally)

            assert.is.truthy(run.luarocks_bool("pack test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("test-1.0-1.src.rock"))

            assert.is.truthy(run.luarocks_bool("unpack test-1.0-1.src.rock"))
            assert.is.truthy(lfs.attributes("test-1.0-1/test.lua"))
         end, finally)
      end)

      it("can pack a rockspec with a bare file:// fails if doesn't exist", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test_doesnt_exist.lua"
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
            ]], finally)

            assert.is.falsy(run.luarocks_bool("pack test-1.0-1.rockspec"))
            assert.is.falsy(lfs.attributes("test-1.0-1.src.rock"))
         end, finally)
      end)


      it("fails packing a rockspec into a .src.rock if dir doesn't exist", function()
         local output = run.luarocks("pack " .. testing_paths.fixtures_dir .. "/bad_pack-0.1-1.rockspec")
         assert.match("Directory invalid_dir not found", output)
         assert.is_falsy(lfs.attributes("bad_pack-0.1-1.src.rock"))
      end)

      describe("namespaced dependencies", function()
         it("can pack rockspec with namespaced dependencies", function()
            finally(function()
               os.remove("has_namespaced_dep-1.0-1.src.rock")
            end)
            assert(run.luarocks_bool("pack " .. testing_paths.fixtures_dir .. "/a_repo/has_namespaced_dep-1.0-1.rockspec"))
            assert.is_truthy(lfs.attributes("has_namespaced_dep-1.0-1.src.rock"))
         end)
      end)
   end)
end)
