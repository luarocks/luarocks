local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables
local write_file = test_env.write_file
local git_repo = require("spec.util.git_repo")
local V = test_env.V

local extra_rocks = {
   "/cprint-${CPRINT}.src.rock",
   "/lpeg-${LPEG}.src.rock",
   "/luassert-1.7.0-1.src.rock",
   "/luasocket-${LUASOCKET}.src.rock",
   "/lxsh-${LXSH}.src.rock",
   "/luafilesystem-${LUAFILESYSTEM}.src.rock",
   "/luafilesystem-${LUAFILESYSTEM_OLD}.src.rock",
   "spec/fixtures/a_repo/has_build_dep-1.0-1.all.rock",
   "spec/fixtures/a_repo/a_build_dep-1.0-1.all.rock",
   "spec/fixtures/a_repo/a_rock-1.0-1.src.rock",
}

describe("luarocks install #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("basic tests", function()
      pending("fails with local flag as root #unix", function()
         if test_env.TYPE_TEST_ENV ~= "full" then
            assert.is_false(run.luarocks_bool("install --local luasocket ", { USER = "root" } ))
         end
      end)

      pending("fails with no downloader", function()
         if test_env.TYPE_TEST_ENV ~= "full" then
            local output = assert(run.luarocks("install https://example.com/rock-1.0.src.rock", { LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/testing_config_no_downloader.lua" } ))
            assert.match("no downloader tool", output)

            -- can do http but not https
            assert(run.luarocks("install luasocket"))
            output = assert(run.luarocks("install https://example.com/rock-1.0.src.rock", { LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/testing_config_no_downloader.lua" } ))
            assert.match("no downloader tool", output)
         end
      end)

      it("only-deps of lxsh show there is no lxsh", function()
         assert.is_true(run.luarocks_bool("install lxsh ${LXSH} --only-deps"))
         assert.is_false(run.luarocks_bool("show lxsh"))
      end)

      it("installs a package with a dependency", function()
         assert.is_true(run.luarocks_bool("install has_build_dep"))
         assert.is_true(run.luarocks_bool("show a_rock"))
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
      it('skipping dependency checks', function()
         assert.is_true(run.luarocks_bool("install has_build_dep --nodeps"))
         assert.is_true(run.luarocks_bool("show has_build_dep"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/a_rock"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/has_build_dep"))
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

      it("only-deps of luasocket packed rock", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock luasocket ${LUASOCKET}"))
         local output = run.luarocks("install --only-deps " .. "luasocket-${LUASOCKET}." .. test_env.platform .. ".rock")
         assert.match(V"Successfully installed dependencies for luasocket ${LUASOCKET}", output, 1, true)
         assert.is_true(os.remove("luasocket-${LUASOCKET}." .. test_env.platform .. ".rock"))
      end)

      it("reinstall", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock luasocket ${LUASOCKET}"))
         assert.is_true(run.luarocks_bool("install " .. "luasocket-${LUASOCKET}." .. test_env.platform .. ".rock"))
         assert.is_true(run.luarocks_bool("install --deps-mode=none " .. "luasocket-${LUASOCKET}." .. test_env.platform .. ".rock"))
         assert.is_true(os.remove("luasocket-${LUASOCKET}." .. test_env.platform .. ".rock"))
      end)

      it("binary rock of cprint", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock cprint"))
         assert.is_true(run.luarocks_bool("install cprint-${CPRINT}." .. test_env.platform .. ".rock"))
         assert.is_true(os.remove("cprint-${CPRINT}." .. test_env.platform .. ".rock"))
      end)

      it("accepts --no-manifest flag", function()
         assert.is_true(run.luarocks_bool("install lxsh ${LXSH}"))
         assert.is.truthy(lfs.attributes(testing_paths.testing_sys_rocks .. "/manifest"))
         assert.is.truthy(os.remove(testing_paths.testing_sys_rocks .. "/manifest"))

         assert.is_true(run.luarocks_bool("install --no-manifest lxsh ${LXSH}"))
         assert.is.falsy(lfs.attributes(testing_paths.testing_sys_rocks .. "/manifest"))
      end)
   end)

   describe("#build_dependencies", function()
      it("install does not install a build dependency", function()
         assert(run.luarocks_bool("install has_build_dep"))
         assert(run.luarocks_bool("show has_build_dep 1.0"))
         assert.falsy(run.luarocks_bool("show a_build_dep 1.0"))
      end)
   end)

   it("respects luarocks.lock in package #pinning", function()
      test_env.run_in_tmp(function(tmpdir)
         write_file("test-1.0-1.rockspec", [[
            package = "test"
            version = "1.0-1"
            source = {
               url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
            }
            dependencies = {
               "a_rock >= 0.8"
            }
            build = {
               type = "builtin",
               modules = {
                  test = "test.lua"
               }
            }
         ]])
         write_file("test.lua", "return {}")
         write_file("luarocks.lock", [[
            return {
               dependencies = {
                  ["a_rock"] = "1.0-1",
               }
            }
         ]])

         assert.is_true(run.luarocks_bool("make --pack-binary-rock --server=" .. testing_paths.fixtures_dir .. "/a_repo test-1.0-1.rockspec"))
         assert.is_true(os.remove("luarocks.lock"))

         assert.is.truthy(lfs.attributes("./test-1.0-1.all.rock"))

         assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/test-1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))

         print(run.luarocks("install ./test-1.0-1.all.rock --tree=lua_modules --server=" .. testing_paths.fixtures_dir .. "/a_repo"))

         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/test-1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/test/1.0-1/luarocks.lock"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. test_env.lua_version .. "/a_rock/2.0-1"))
      end, finally)
   end)

   describe("#unix install runs build from #git", function()
      local git

      lazy_setup(function()
         git = git_repo.start()
      end)

      lazy_teardown(function()
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
