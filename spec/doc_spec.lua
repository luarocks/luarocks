local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

describe("luarocks doc #integration", function()
   before_each(function()
      test_env.setup_specs()
   end)

   describe("basic tests", function()
      it("with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("doc"))
      end)

      it("with invalid argument", function()
         assert.is_false(run.luarocks_bool("doc invalid"))
      end)

      it("with no homepage and no doc folder", function()
         test_env.run_in_tmp(function(tmpdir)
            test_env.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://test.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            test_env.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("install test-1.0-1.rockspec"))
            assert.is_false(run.luarocks_bool("doc test --home"))
         end, finally)
      end)

      it("with no doc folder but with homepage", function()
         test_env.run_in_tmp(function(tmpdir)
            test_env.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://test.lua"
               }
               description = {
                  homepage = "http://www.example.com"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            test_env.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("install test-1.0-1.rockspec"))
            local output = assert.is.truthy(run.luarocks("doc test"))
            assert.is.truthy(output:find("documentation directory not found"))
         end, finally)
      end)
   end)

   describe("#namespaces", function()
      it("retrieves docs for a namespaced package from the command-line", function()
         assert(run.luarocks_bool("build a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("build a_rock 1.0 --keep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert.match("a_rock 2.0", run.luarocks("doc a_user/a_rock"))
      end)
   end)

   describe("tests with flags", function()
      it("of installed package", function()
         test_env.run_in_tmp(function(tmpdir)
            test_env.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://test.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            test_env.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("install test-1.0-1.rockspec"))
            lfs.mkdir(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc")
            test_env.write_file(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc/doc.md", "",  finally)
            test_env.write_file(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc/readme.md", "", finally)
            assert.is_true(run.luarocks_bool("doc test"))
         end, finally)
      end)

      it("with --list", function()
         test_env.run_in_tmp(function(tmpdir)
            test_env.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://test.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            test_env.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("install test-1.0-1.rockspec"))
            lfs.mkdir(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc")
            test_env.write_file(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc/doc1.md", "",  finally)
            test_env.write_file(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc/doc2.md", "", finally)
            local output = assert.is.truthy(run.luarocks("doc test --list"))
            assert.is.truthy(output:find("doc1%.md"))
            assert.is.truthy(output:find("doc2%.md"))
         end, finally)
      end)

      it("with --porcelain", function()
         test_env.run_in_tmp(function(tmpdir)
            test_env.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://test.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            test_env.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("install test-1.0-1.rockspec"))
            lfs.mkdir(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc")
            test_env.write_file(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc/doc1.md", "",  finally)
            test_env.write_file(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc/doc2.md", "", finally)
            assert.is_true(run.luarocks_bool("doc test --porcelain"))
         end, finally)
      end)
   end)
end)
