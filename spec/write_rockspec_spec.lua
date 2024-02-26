local test_env = require("spec.util.test_env")
local git_repo = require("spec.util.git_repo")
local lfs = require("lfs")
local run = test_env.run

describe("luarocks write_rockspec tests #integration", function()

   lazy_setup(function()
      test_env.setup_specs()
   end)

   it("fails with invalid argument", function()
      assert.is_false(run.luarocks_bool("write_rockspec invalid"))
   end)

   it("fails with invalid zip", function()
      assert.is_false(run.luarocks_bool("write_rockspec http://example.com/invalid.zip"))
   end)

   describe("from #git #unix", function()
      local git

      lazy_setup(function()
         git = git_repo.start()
      end)

      teardown(function()
         git:stop()
      end)

      it("runs with no flags/arguments", function()
         local d = lfs.currentdir()
         finally(function()
            os.remove("testrock-dev-1.rockspec")
            lfs.chdir(d)
            test_env.remove_dir("testrock")
         end)
         os.execute("git clone git://localhost/testrock")
         lfs.chdir("testrock")
         assert.is_true(run.luarocks_bool("write_rockspec"))
         assert.is.truthy(lfs.attributes("testrock-dev-1.rockspec"))
      end)

      it("runs", function()
         finally(function() os.remove("testrock-dev-1.rockspec") end)
         assert.is_true(run.luarocks_bool("write_rockspec git://localhost/testrock"))
         assert.is.truthy(lfs.attributes("testrock-dev-1.rockspec"))
      end)

      it("runs with --tag", function()
         finally(function() os.remove("testrock-2.3.0-1.rockspec") end)
         assert.is_true(run.luarocks_bool("write_rockspec git://localhost/testrock --tag=v2.3.0"))
         assert.is.truthy(lfs.attributes("testrock-2.3.0-1.rockspec"))
         -- TODO check contents
      end)

      it("runs with format flag", function()
         finally(function() os.remove("testrock-dev-1.rockspec") end)
         assert.is_true(run.luarocks_bool("write_rockspec git://localhost/testrock --rockspec-format=1.1 --lua-versions=5.1,5.2"))
         assert.is.truthy(lfs.attributes("testrock-dev-1.rockspec"))
         -- TODO check contents
      end)

      it("runs with full flags", function()
         finally(function() os.remove("testrock-dev-1.rockspec") end)
         assert.is_true(run.luarocks_bool("write_rockspec git://localhost/testrock --lua-versions=5.1,5.2 --license=\"MIT/X11\" "
                                             .. " --homepage=\"http://www.luarocks.org\" --summary=\"A package manager for Lua modules\" "))
         assert.is.truthy(lfs.attributes("testrock-dev-1.rockspec"))
         -- TODO check contents
      end)

      it("with various flags", function()
         finally(function() os.remove("testrock-dev-1.rockspec") end)
         assert.is_true(run.luarocks_bool("write_rockspec git://localhost/testrock --lib=fcgi --license=\"3-clause BSD\" " .. "--lua-versions=5.1,5.2"))
         assert.is.truthy(lfs.attributes("testrock-dev-1.rockspec"))
         -- TODO check contents
      end)
   end)

   describe("from tarball #mock", function()

      lazy_setup(function()
         test_env.setup_specs(nil, "mock")
         test_env.mock_server_init()
      end)
      lazy_teardown(function()
         test_env.mock_server_done()
      end)

      it("via http", function()
         finally(function() os.remove("an_upstream_tarball-0.1-1.rockspec") end)
         assert.is_true(run.luarocks_bool("write_rockspec http://localhost:8080/file/an_upstream_tarball-0.1.tar.gz --lua-versions=5.1"))
         assert.is.truthy(lfs.attributes("an_upstream_tarball-0.1-1.rockspec"))
         -- TODO check contents
      end)

      it("with a different basedir", function()
         finally(function() os.remove("renamed_upstream_tarball-0.1-1.rockspec") end)
         assert.is_true(run.luarocks_bool("write_rockspec http://localhost:8080/file/renamed_upstream_tarball-0.1.tar.gz --lua-versions=5.1"))
         assert.is.truthy(lfs.attributes("renamed_upstream_tarball-0.1-1.rockspec"))
         -- TODO check contents
      end)
   end)
end)
