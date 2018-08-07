local test_env = require("spec.util.test_env")
local testing_paths = test_env.testing_paths
local run = test_env.run

test_env.unload_luarocks()
local luarocks = require("luarocks")
test_env.setup_specs()

describe("LuaRocks api tests #unit", function()
   setup(function()
      if test_env.TRAVIS or test_env.APPVEYOR then
         luarocks.setup({
            lua_dir = testing_paths.luadir,
            lua_incdir = testing_paths.luadir .. "/include",
            lua_libdir = testing_paths.luadir .. "/lib"
         })
      else
         luarocks.setup()
      end
   end)
   describe("luarocks.homepage", function()
      it("returns the homepage of an installed package", function()
         luarocks.set_rocks_servers(testing_paths.fixtures_dir .. "/a_repo", "only")
         assert.truthy(luarocks.install("a_rock", "1.0-1", testing_paths.testing_sys_tree))
         assert.truthy(luarocks.homepage("a_rock"))
      end)

      it("returns the homepage of a non-installed package", function()
         luarocks.set_rocks_servers(testing_paths.fixtures_dir .. "/a_repo", "only")
         assert.truthy(luarocks.homepage("a_rock"))
      end)

      it("returns false if a homepage doesn't exist for the requested package", function()
         luarocks.set_rocks_servers(testing_paths.fixtures_dir .. "/a_repo", "only")

         local result, err = luarocks.homepage("busted_project")
         assert.falsy(result)
         assert.truthy(err:find("No homepage defined"))
      end)
   end)

   describe("luarocks.doc", function()
      it("returns false if the requested package is not installed", function()
         local result, err = luarocks.doc("a_rock")

         assert.falsy(result)
         assert.truthy(err:find("not installed"))
      end)

      it("returns false if no documentation directory exists for the requested package", function()
         luarocks.set_rocks_servers(testing_paths.fixtures_dir .. "/a_repo", "only")
         assert.truthy(luarocks.install("a_rock", "1.0-1", testing_paths.testing_sys_tree))
         local result, err = luarocks.doc("a_rock", "1.0-1", testing_paths.testing_sys_tree)

         assert.falsy(result)
         assert.truthy(err:find("documentation directory not found"))
      end)

      -- Skip until luarocks-api is rebased onto master and run_in_tmp becomes available
      pending("returns the documentation directory and files of the requested package", function()
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

            assert.truthy(luarocks.install("test-1.0-1.rockspec", nil, testing_paths.testing_sys_tree))
            lfs.mkdir(testing_paths.testing_sys_rocks .. "/test/1.0-1/doc")
            local docdir, docfile, files = luarocks.doc("test", "1.0-1", testing_paths.testing_sys_tree)

            assert.truthy(docdir:find("doc"))
            assert.truthy(docfile:lower():find("readme%.md"))
            assert.truthy(files[1]:find("doc1%.md") or files[1]:find("doc2%.md"))
            assert.truthy(files[2]:find("doc1%.md") or files[2]:find("doc2%.md"))
         end, finally)
      end)
   end)

   describe("luarocks.list", function()
      it("returns a list of packages that match the given filter criteria", function()
         luarocks.set_rocks_servers(testing_paths.fixtures_dir .. "/a_repo", "only")
         assert.truthy(luarocks.install("a_rock", "1.0-1", testing_paths.testing_sys_tree))

         local result = luarocks.list("a_rock", false, "1.0-1", testing_paths.testing_sys_tree)
         assert.truthy(result)
         assert.truthy(result["a_rock"])
      end)

      -- Skip until luarocks-api is rebased onto master and run_in_tmp becomes available
      pending("returns a list of packages that are outdated", function()
         test_env.run_in_tmp(function(tmpdir)
            luarocks.set_rocks_servers(testing_paths.fixtures_dir .. "/a_repo", "only")

            test_env.write_file("a_rock-0.0-1.rockspec", [[
               package = "a_rock"
               version = "0.0-1"
               source = {
                  url = "file://a_rock.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     a_rock = "a_rock.lua"
                  }
               }
            ]], finally)
            test_env.write_file("a_rock.lua", "return {}", finally)

            assert.truthy(luarocks.install("a_rock-0.0-1.rockspec", nil, testing_paths.testing_sys_tree))
            
            local result = luarocks.list("a_rock", true, "0.0-1", testing_paths.testing_sys_tree)
            assert.truthy(result)
            assert.same(result["installed"], "0.0-1")
            assert.same(result["available"], "1.0-1")
         end, finally)
      end)
   end)

   describe("luarocks.search", function()
      it("returns a search table with information about the requested package", function()
         luarocks.set_rocks_servers(testing_paths.fixtures_dir .. "/a_repo", "only")

         local result
         result = luarocks.search("a_rock", "1.0-1")
         assert.truthy(result["sources"])
         result = luarocks.search("a_rock", "1.0-1", "binary")
         assert.falsy(result["sources"])
      end)
   end)
end)
