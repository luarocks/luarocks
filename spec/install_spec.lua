local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables
local write_file = test_env.write_file
local git_repo = require("spec.util.git_repo")

test_env.unload_luarocks()

local extra_rocks = {
   "/cprint-0.1-2.src.rock",
   "/cprint-0.1-2.rockspec",
   "/lpeg-0.12-1.src.rock",
   "/luasec-0.6-1.rockspec",
   "/luassert-1.7.0-1.src.rock",
   "/luasocket-3.0rc1-2.src.rock",
   "/luasocket-3.0rc1-2.rockspec",
   "/lxsh-0.8.6-2.src.rock",
   "/lxsh-0.8.6-2.rockspec",
   "/say-1.2-1.src.rock",
   "/say-1.0-1.src.rock",
   "/wsapi-1.6-1.src.rock",
   "/luafilesystem-1.6.3-2.src.rock",
   "/luafilesystem-1.6.3-1.src.rock",
   "/sailor-0.5-3.src.rock",
   "/sailor-0.5-4.src.rock",
}

describe("luarocks install #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("basic tests", function()
      it("fails with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("install"))
      end)

      it("fails with invalid argument", function()
         assert.is_false(run.luarocks_bool("install invalid"))
      end)

      it("fails invalid patch", function()
         assert.is_false(run.luarocks_bool("install " .. testing_paths.fixtures_dir .. "/invalid_patch-0.1-1.rockspec"))
      end)      

      it("fails invalid rock", function()
         assert.is_false(run.luarocks_bool("install \"invalid.rock\" "))
      end)

      it("fails with local flag as root #unix", function()
         assert.is_false(run.luarocks_bool("install --local luasocket ", { USER = "root" } ))
      end)

      it("fails not a zip file", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("not_a_zipfile-1.0-1.src.rock", [[
               I am not a .zip file!
            ]], finally)
            assert.is_false(run.luarocks_bool("install not_a_zipfile-1.0-1.src.rock"))
         end, finally)
      end)

      it("only-deps of lxsh show there is no lxsh", function()
         assert.is_true(run.luarocks_bool("install lxsh 0.8.6-2 --only-deps"))
         assert.is_false(run.luarocks_bool("show lxsh"))
      end)

      it("fails with incompatible architecture", function()
         assert.is_false(run.luarocks_bool("install \"foo-1.0-1.impossible-x86.rock\" "))
      end)

      it("installs a package with an executable", function()
         assert(run.luarocks_bool("install wsapi"))
      end)

      it("installs a package with a dependency", function()
         assert.is_true(run.luarocks_bool("install luasec " .. test_env.openssl_dirs))
         assert.is_true(run.luarocks_bool("show luasocket"))
      end)

      it("installs a package without its documentation #only", function()
         assert.is_true(run.luarocks_bool("install wsapi 1.6 --no-doc"))
         assert.is_true(run.luarocks_bool("show wsapi 1.6"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/wsapi/1.6-1/doc"))
      end)
   end)
   
   describe("#namespaces", function()
      it("installs a namespaced package from the command-line", function()
         assert(run.luarocks_bool("install a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/2.0-1/rock_namespace"))
      end)

      it("installs a namespaced package given an URL and any string in --namespace", function()
         -- This is not a "valid" namespace (as per luarocks.org rules)
         -- but we're not doing any format checking in the luarocks codebase
         -- so this keeps our options open.
         assert(run.luarocks_bool("install --namespace=x.y@z file://" .. testing_paths.fixtures_dir .. "/a_rock-1.0-1.src.rock" ))
         assert.truthy(run.luarocks_bool("show a_rock 1.0"))
         local fd = assert(io.open(testing_paths.testing_sys_rocks .. "/a_rock/1.0-1/rock_namespace", "r"))
         finally(function() fd:close() end)
         assert.same("x.y@z", fd:read("*l"))
      end)

      it("installs a package with a namespaced dependency", function()
         assert(run.luarocks_bool("install has_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show has_namespaced_dep"))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/2.0-1/rock_namespace"))
      end)

      it("installs a package reusing a namespaced dependency", function()
         assert(run.luarocks_bool("install a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("install has_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" )
         assert.has.no.match("Missing dependencies", output)
      end)

      it("installs a package considering namespace of locally installed package", function()
         assert(run.luarocks_bool("install a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("install has_another_namespaced_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" )
         assert.has.match("Missing dependencies", output)
         print(output)
         assert(run.luarocks_bool("show a_rock 3.0"))
      end)
   end)

   describe("more complex tests", function()
      it('luasec with skipping dependency checks', function()
         assert.is_true(run.luarocks_bool("install luasec " .. test_env.openssl_dirs .. " --nodeps"))
         assert.is_true(run.luarocks_bool("show luasec"))
         if env_variables.TYPE_TEST_ENV == "minimal" then
            assert.is_false(run.luarocks_bool(test_env.quiet("show luasocket")))
            assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/luasocket"))
         end
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/luasec"))
      end)

      it('handle relative path in --tree #632', function()
         local relative_path = "./temp_dir_"..math.random(100000)
         if test_env.TEST_TARGET_OS == "windows" then
            relative_path = relative_path:gsub("/", "\\")
         end
         test_env.remove_dir(relative_path)
         assert.is.falsy(lfs.attributes(relative_path))
         assert.is_true(run.luarocks_bool("install luafilesystem --tree="..relative_path))
         assert.is.truthy(lfs.attributes(relative_path))
         test_env.remove_dir(relative_path)
         assert.is.falsy(lfs.attributes(relative_path))
      end)

      it('handle versioned modules when installing another version with --keep #268', function()
         assert.is_true(run.luarocks_bool("install luafilesystem"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/lfs."..test_env.lib_extension))

         assert.is_true(run.luarocks_bool("install luafilesystem 1.6.3-1 --keep"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/lfs."..test_env.lib_extension))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/luafilesystem_1_6_3_1-lfs."..test_env.lib_extension))

         assert.is_true(run.luarocks_bool("install luafilesystem"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/lfs."..test_env.lib_extension))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/lib/lua/"..env_variables.LUA_VERSION.."/luafilesystem_1_6_3_1-lfs."..test_env.lib_extension))
      end)

      it('handle non-Lua files in build.install.lua when upgrading sailorproject/sailor#138', function()
         assert.is_true(run.luarocks_bool("install sailor 0.5-3 --deps-mode=none"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/sailor/blank-app/.htaccess"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/sailor/blank-app/.htaccess~"))

         assert.is_true(run.luarocks_bool("install sailor 0.5-4 --deps-mode=none"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/sailor/blank-app/.htaccess"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_tree .. "/share/lua/"..env_variables.LUA_VERSION.."/sailor/blank-app/.htaccess~"))
      end)
      
      it("only-deps of luasocket packed rock", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock luasocket 3.0rc1-2"))
         local output = run.luarocks("install --only-deps " .. "luasocket-3.0rc1-2." .. test_env.platform .. ".rock")
         assert.are.same("Successfully installed dependencies for luasocket 3.0rc1-2", output:gsub("\n", ""))
         assert.is_true(os.remove("luasocket-3.0rc1-2." .. test_env.platform .. ".rock"))
      end)

      it("reinstall", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock luasocket 3.0rc1-2"))
         assert.is_true(run.luarocks_bool("install " .. "luasocket-3.0rc1-2." .. test_env.platform .. ".rock"))
         assert.is_true(run.luarocks_bool("install --deps-mode=none " .. "luasocket-3.0rc1-2." .. test_env.platform .. ".rock"))
         assert.is_true(os.remove("luasocket-3.0rc1-2." .. test_env.platform .. ".rock"))
      end)

      it("binary rock of cprint", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock cprint"))
         assert.is_true(run.luarocks_bool("install cprint-0.1-2." .. test_env.platform .. ".rock"))
         assert.is_true(os.remove("cprint-0.1-2." .. test_env.platform .. ".rock"))
      end)     
   end)

   describe("New install functionality based on pull request 552", function()
      it("break dependencies warning", function() 
         assert.is_true(run.luarocks_bool("install say 1.2"))
         assert.is_true(run.luarocks_bool("install luassert"))
         assert.is_true(run.luarocks_bool("install say 1.0"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/say/1.2-1"))
      end)
      it("break dependencies force", function() 
         assert.is_true(run.luarocks_bool("install say 1.2"))
         assert.is_true(run.luarocks_bool("install luassert"))
         local output = run.luarocks("install --force say 1.0")
         assert.is.truthy(output:find("Checking stability of dependencies"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/say/1.2-1"))
      end)
      it("break dependencies force fast", function() 
         assert.is_true(run.luarocks_bool("install say 1.2"))
         assert.is_true(run.luarocks_bool("install luassert"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/say/1.2-1"))
         local output = run.luarocks("install --force-fast say 1.0")
         assert.is.falsy(output:find("Checking stability of dependencies"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/say/1.0-1"))
      end)
   end)

   describe("#build_dependencies", function()
      it("install does not install a build dependency", function()
         assert(run.luarocks_bool("install has_build_dep --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(run.luarocks_bool("show has_build_dep 1.0"))
         assert.falsy(run.luarocks_bool("show a_build_dep 1.0"))
      end)
   end)

   describe("#unix install runs build from #git", function()
      local git

      setup(function()
         git = git_repo.start()
      end)
      
      teardown(function()
         if git then
            git:stop()
         end
      end)

      it("using --branch", function()
         write_file("my_branch-1.0-1.rockspec", [[
            rockspec_format = "3.0"
            package = "my_branch"
            version = "1.0-1"
            source = {
               url = "git://localhost/testrock"
            }
         ]], finally)
         assert.is_false(run.luarocks_bool("install --branch unknown-branch ./my_branch-1.0-1.rockspec"))
         assert.is_true(run.luarocks_bool("install --branch test-branch ./my_branch-1.0-1.rockspec"))
      end)
   end)

end)
