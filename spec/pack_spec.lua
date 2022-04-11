local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

test_env.unload_luarocks()

local extra_rocks = {
   "/luassert-1.7.0-1.src.rock",
   "/luasocket-${LUASOCKET}.src.rock",
   "/luasocket-${LUASOCKET}.rockspec",
   "/say-1.2-1.src.rock",
   "/say-1.0-1.src.rock"
}

describe("luarocks pack #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("pack"))
   end)

   it("basic", function()
      assert(run.luarocks_bool("pack luacov"))
      assert(test_env.remove_files(lfs.currentdir(), "luacov%-"))
   end)

   it("invalid rockspec", function()
      assert.is_false(run.luarocks_bool("pack " .. testing_paths.fixtures_dir .. "/invalid_say-1.3-1.rockspec"))
   end)

   it("not installed rock", function()
      assert.is_false(run.luarocks_bool("pack cjson"))
   end)

   it("not installed rock from non existing manifest", function()
      assert.is_false(run.luarocks_bool("pack /non/exist/temp.manif"))
   end)

   it("detects latest version version of rock", function()
      assert(run.luarocks_bool("install say 1.2"))
      assert(run.luarocks_bool("install luassert"))
      assert(run.luarocks_bool("install say 1.0"))
      assert(run.luarocks_bool("pack say"))
      assert.is_truthy(lfs.attributes("say-1.2-1.all.rock"))
      assert(test_env.remove_files(lfs.currentdir(), "say%-"))
   end)

   pending("#gpg --sign", function()
      assert(run.luarocks_bool("install say 1.2"))
      assert(run.luarocks_bool("install luassert"))
      assert(run.luarocks_bool("install say 1.0"))
      os.delete("say-1.2-1.all.rock")
      os.delete("say-1.2-1.all.rock.asc")
      assert(run.luarocks_bool("pack say --sign"))
      assert.is_truthy(lfs.attributes("say-1.2-1.all.rock"))
      assert.is_truthy(lfs.attributes("say-1.2-1.all.rock.asc"))
      assert(test_env.remove_files(lfs.currentdir(), "say%-"))
   end)

   describe("#mock", function()

      setup(function()
         test_env.mock_server_init()
      end)

      teardown(function()
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

   describe("#namespaces", function()
      it("packs a namespaced rock", function()
         finally(function()
            os.remove("a_rock-2.0-1.all.rock")
         end)
         assert(run.luarocks_bool("build a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("build a_rock --keep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("pack a_user/a_rock" ))
         assert(lfs.attributes("a_rock-2.0-1.all.rock"))
      end)
   end)

end)
