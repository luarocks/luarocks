local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

test_env.unload_luarocks()

local extra_rocks = test_env.mock_server_extra_rocks({
   "/luasec-0.6-1.rockspec",
   "/luassert-1.7.0-1.src.rock",
   "/luasocket-3.0rc1-2.src.rock",
   "/luasocket-3.0rc1-2.rockspec",
   "/say-1.2-1.src.rock",
   "/say-1.0-1.src.rock"
})

describe("LuaRocks pack #blackbox #b_pack", function()

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
      assert.is_false(run.luarocks_bool("pack " .. testing_paths.fixtures_dir .. "/invalid_validate-args-1.5.4-1.rockspec"))
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

   it("src", function()
      assert(run.luarocks_bool("install luasec " .. test_env.OPENSSL_DIRS))
      assert(run.luarocks_bool("download --rockspec luasocket 3.0rc1-2"))
      assert(run.luarocks_bool("pack luasocket-3.0rc1-2.rockspec"))
      assert(test_env.remove_files(lfs.currentdir(), "luasocket%-"))
   end)
   
   describe("#mock namespaced dependencies", function()

      setup(function()
         test_env.mock_server_init()
      end)
      
      teardown(function()
         test_env.mock_server_done()
      end)

      it("can pack rockspec with namespaced dependencies", function()
         finally(function()
            os.remove("has_namespaced_dep-1.0-1.src.rock")
         end)
         assert(run.luarocks_bool("pack " .. testing_paths.fixtures_dir .. "/a_repo/has_namespaced_dep-1.0-1.rockspec"))
         assert.is_truthy(lfs.attributes("has_namespaced_dep-1.0-1.src.rock"))
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


