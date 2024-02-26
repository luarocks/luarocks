local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

describe("luarocks show #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   it("with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("show"))
   end)

   describe("basic tests with flags", function()
      it("invalid", function()
         assert.is_false(run.luarocks_bool("show invalid"))
      end)

      it("luacov", function()
         local output = run.luarocks("show luacov")
         assert.is.truthy(output:match("LuaCov"))
      end)

      it("luacov with uppercase name", function()
         local output = run.luarocks("show LuaCov")
         assert.is.truthy(output:match("LuaCov"))
      end)

      it("modules of luacov", function()
         local output = run.luarocks("show --modules luacov")
         assert.match("luacov.*luacov.defaults.*luacov.reporter.*luacov.reporter.default.*luacov.runner.*luacov.stats.*luacov.tick", output)
      end)

      it("--deps", function()
         assert(run.luarocks_bool("build has_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         local output = run.luarocks("show --deps has_namespaced_dep")
         assert.match("a_user/a_rock", output)
      end)

      it("list dependencies", function()
         assert(run.luarocks_bool("build has_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         local output = run.luarocks("show has_namespaced_dep")
         assert.match("a_user/a_rock.*2.0", output)
      end)

      it("rockspec of luacov", function()
         local output = run.luarocks("show --rockspec luacov")
         assert.is.truthy(output:match("luacov--0.15.0--1.rockspec"))
      end)

      it("mversion of luacov", function()
         local output = run.luarocks("show --mversion luacov")
         assert.is.truthy(output:match("0.15.0--1"))
      end)

      it("rock tree of luacov", function()
         local output = run.luarocks("show --rock-tree luacov")
      end)

      it("rock directory of luacov", function()
         local output = run.luarocks("show --rock-dir luacov")
      end)

      it("issues URL of luacov", function()
         local output = run.luarocks("show --issues luacov")
      end)

      it("labels of luacov", function()
         local output = run.luarocks("show --labels luacov")
      end)
   end)

   it("old version of luacov", function()
      run.luarocks("install luacov 0.15.0")
      run.luarocks_bool("show luacov 0.15.0")
   end)

   it("can find by substring", function()
      assert(run.luarocks_bool("install has_build_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
      assert.match("a_build_dep", run.luarocks("show has_"))
   end)

   it("fails when substring matches multiple", function()
      assert(run.luarocks_bool("install has_build_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
      assert(run.luarocks_bool("install a_build_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
      assert.match("multiple installed packages match the name 'dep'", run.luarocks("show dep"))
   end)

   it("shows #build_dependencies", function()
      assert(run.luarocks_bool("install has_build_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
      assert.match("a_build_dep", run.luarocks("show has_build_dep"))
   end)

   it("gets #build_dependencies via --build-deps", function()
      assert(run.luarocks_bool("install has_build_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
      assert.match("a_build_dep", run.luarocks("show has_build_dep --build-deps"))
   end)

   it("shows #namespaces via --rock-namespace", function()
      assert(run.luarocks_bool("build a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
      assert.match("a_user", run.luarocks("show a_rock --rock-namespace"))
   end)

end)
