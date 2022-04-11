local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = {
   "/abelhas-1.1-1.rockspec",
   "/lpeg-${LPEG}.rockspec"
}

describe("luarocks new_version #integration", function()

   setup(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("basic tests", function()
      it("with no flags/arguments", function()
         finally(function()
            lfs.chdir(testing_paths.testrun_dir)
            test_env.remove_dir("empty")
         end)
         assert(lfs.mkdir("empty"))
         assert(lfs.chdir("empty"))
         assert.is_false(run.luarocks_bool("new_version"))
      end)

      it("with invalid", function()
         assert.is_false(run.luarocks_bool("new_version invalid"))
      end)

      it("with invalid url", function()
         assert.is_true(run.luarocks_bool("download --rockspec abelhas 1.1"))
         assert.is_true(run.luarocks_bool("new_version abelhas-1.1-1.rockspec 1.1 http://luainvalid"))
         assert.is.truthy(lfs.attributes("abelhas-1.1-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "abelhas%-")
      end)
   end)

   describe("more complex tests", function()
      it("of luacov", function()
         assert.is_true(run.luarocks_bool("download --rockspec luacov ${LUACOV_V}"))
         assert.is_true(run.luarocks_bool("new_version luacov-${LUACOV}.rockspec 0.2"))
         assert.is.truthy(lfs.attributes("luacov-0.2-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "luacov%-")
      end)

      it("url of abelhas", function()
         assert.is_true(run.luarocks_bool("download --rockspec abelhas 1.1"))
         assert.is_true(run.luarocks_bool("new_version abelhas-1.1-1.rockspec 1.2 http://example.com/abelhas-1.2.tar.gz"))
         assert.is.truthy(lfs.attributes("abelhas-1.2-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "abelhas%-")
      end)

      it("of luacov with tag", function()
         assert.is_true(run.luarocks_bool("download --rockspec luacov ${LUACOV_V}"))
         assert.is_true(run.luarocks_bool("new_version luacov-${LUACOV}.rockspec --tag v0.3"))
         assert.is.truthy(lfs.attributes("luacov-0.3-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "luacov%-")
      end)

      it("updating md5", function()
         assert.is_true(run.luarocks_bool("download --rockspec lpeg ${LPEG_V}"))
         assert.is_true(run.luarocks_bool("new_version lpeg-${LPEG}.rockspec 0.2 https://luarocks.org/manifests/gvvaughan/lpeg-1.0.0-1.rockspec"))
         test_env.remove_files(lfs.currentdir(), "lpeg%-")
      end)
   end)

   describe("remote tests #mock", function()
      setup(function()
         test_env.mock_server_init()
      end)
      teardown(function()
         test_env.mock_server_done()
      end)
      it("with remote spec", function()
         assert.is_true(run.luarocks_bool("new_version http://localhost:8080/file/a_rock-1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("a_rock-1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("a_rock-1.0-2.rockspec"))
         test_env.remove_files(lfs.currentdir(), "luasocket%-")
      end)
   end)

end)
