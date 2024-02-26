local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths
local copy_dir = test_env.copy_dir
local is_win = test_env.TEST_TARGET_OS == "windows"
local write_file = test_env.write_file
local lfs = require("lfs")

describe("luarocks init #integration", function()

   lazy_setup(function()
      test_env.setup_specs()
   end)

   it("with no arguments", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init"))
         if is_win then
            assert.truthy(lfs.attributes(myproject .. "/lua.bat"))
            assert.truthy(lfs.attributes(myproject .. "/luarocks.bat"))
         else
            assert.truthy(lfs.attributes(myproject .. "/lua"))
            assert.truthy(lfs.attributes(myproject .. "/luarocks"))
         end
         assert.truthy(lfs.attributes(myproject .. "/lua_modules"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks/config-" .. test_env.lua_version .. ".lua"))
         assert.truthy(lfs.attributes(myproject .. "/.gitignore"))
         assert.truthy(lfs.attributes(myproject .. "/myproject-dev-1.rockspec"))
      end, finally)
   end)

   it("with --no-gitignore", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init --no-gitignore"))
         if is_win then
            assert.truthy(lfs.attributes(myproject .. "/lua.bat"))
            assert.truthy(lfs.attributes(myproject .. "/luarocks.bat"))
         else
            assert.truthy(lfs.attributes(myproject .. "/lua"))
            assert.truthy(lfs.attributes(myproject .. "/luarocks"))
         end
         assert.truthy(lfs.attributes(myproject .. "/lua_modules"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks/config-" .. test_env.lua_version .. ".lua"))
         assert.falsy(lfs.attributes(myproject .. "/.gitignore"))
         assert.truthy(lfs.attributes(myproject .. "/myproject-dev-1.rockspec"))
      end, finally)
   end)

   it("with --no-wrapper-scripts", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init --no-wrapper-scripts"))
         assert.falsy(lfs.attributes(myproject .. "/lua.bat"))
         assert.falsy(lfs.attributes(myproject .. "/luarocks.bat"))
         assert.falsy(lfs.attributes(myproject .. "/lua"))
         assert.falsy(lfs.attributes(myproject .. "/luarocks"))
         assert.truthy(lfs.attributes(myproject .. "/lua_modules"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks/config-" .. test_env.lua_version .. ".lua"))
         assert.truthy(lfs.attributes(myproject .. "/.gitignore"))
         assert.truthy(lfs.attributes(myproject .. "/myproject-dev-1.rockspec"))
      end, finally)
   end)

   it("with --wrapper-dir", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init --wrapper-dir=./bin"))
         if is_win then
            assert.truthy(lfs.attributes(myproject .. "/bin/lua.bat"))
            assert.truthy(lfs.attributes(myproject .. "/bin/luarocks.bat"))
         else
            assert.truthy(lfs.attributes(myproject .. "/bin/lua"))
            assert.truthy(lfs.attributes(myproject .. "/bin/luarocks"))
         end
         assert.truthy(lfs.attributes(myproject .. "/lua_modules"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks/config-" .. test_env.lua_version .. ".lua"))
         assert.truthy(lfs.attributes(myproject .. "/.gitignore"))
         assert.truthy(lfs.attributes(myproject .. "/myproject-dev-1.rockspec"))
      end, finally)
   end)

   it("lua wrapper works", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init"))
         if is_win then
            assert.truthy(lfs.attributes(myproject .. "/lua.bat"))
            assert.truthy(lfs.attributes(myproject .. "/luarocks.bat"))
            local pd = assert(io.popen([[echo print(_VERSION) | lua.bat]], "r"))
            local output = pd:read("*a")
            pd:close()
            assert.match("5", output, 1, true)
            local fd = io.open("hello.lua", "w")
            fd:write("print('hello' .. _VERSION)")
            fd:close()
            pd = assert(io.popen([[lua.bat hello.lua]], "r"))
            output = pd:read("*a")
            pd:close()
            assert.match("hello", output, 1, true)
         else
            assert.truthy(lfs.attributes(myproject .. "/lua"))
            assert.truthy(lfs.attributes(myproject .. "/luarocks"))
            local pd = assert(io.popen([[echo "print('hello ' .. _VERSION)" | ./lua]], "r"))
            local output = pd:read("*a")
            pd:close()
            assert.match("hello", output, 1, true)
            local fd = io.open("hello.lua", "w")
            fd:write("print('hello' .. _VERSION)")
            fd:close()
            pd = assert(io.popen([[./lua ./hello.lua]], "r"))
            output = pd:read("*a")
            pd:close()
            assert.match("hello", output, 1, true)
         end
      end, finally)
   end)

   it("with given arguments", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init customname 1.0"))
         assert.truthy(lfs.attributes(myproject .. "/customname-1.0-1.rockspec"))
      end, finally)
   end)

   it("with --lua-versions", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init --lua-versions=5.1,5.2,5.3,5.4"))
         local rockspec_name = myproject .. "/myproject-dev-1.rockspec"
         assert.truthy(lfs.attributes(rockspec_name))
         local fd = assert(io.open(rockspec_name, "rb"))
         local data = fd:read("*a")
         fd:close()
         assert.truthy(data:find("lua >= 5.1, < 5.5", 1, true))
      end, finally)
   end)

   it("in a git repo", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         copy_dir(testing_paths.fixtures_dir .. "/git_repo", myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init"))
         local fd = assert(io.open(myproject .. "/myproject-dev-1.rockspec", "r"))
         local content = assert(fd:read("*a"))
         assert.truthy(content:find("summary = \"Test repo\""))
         assert.truthy(content:find("detailed = .+Test repo.+"))
         assert.truthy(content:find("license = \"MIT\""))

         fd = assert(io.open(myproject .. "/.gitignore", "r"))
         content = assert(fd:read("*a"))
         assert.truthy(content:find("/foo"))
         assert.truthy(content:find("/lua"))
         assert.truthy(content:find("/lua_modules"))
      end, finally)
   end)

   it("does not autodetect config or dependencies as modules of the package", function()
      test_env.run_in_tmp(function(tmpdir)
         local myproject = tmpdir .. "/myproject"
         lfs.mkdir(myproject)
         lfs.chdir(myproject)

         assert(run.luarocks("init"))
         assert.truthy(lfs.attributes(myproject .. "/.luarocks/config-" .. test_env.lua_version .. ".lua"))
         local rockspec_filename = myproject .. "/myproject-dev-1.rockspec"
         assert.truthy(lfs.attributes(rockspec_filename))

         -- install a package locally
         write_file("my_dependency-1.0-1.rockspec", [[
            package = "my_dependency"
            version = "1.0-1"
            source = {
               url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/my_dependency.lua"
            }
            build = {
               type = "builtin",
               modules = {
                  my_dependency = "my_dependency.lua"
               }
            }
         ]], finally)
         write_file(tmpdir .. "/my_dependency.lua", "return {}", finally)

         assert.truthy(run.luarocks("build my_dependency-1.0-1.rockspec"))
         assert.truthy(lfs.attributes(myproject .. "/lua_modules/share/lua/" .. test_env.lua_version .."/my_dependency.lua"))

         os.remove(rockspec_filename)
         os.remove("my_dependency-1.0-1.rockspec")

         -- re-run init
         assert(run.luarocks("init"))

         -- file is recreated
         assert.truthy(lfs.attributes(rockspec_filename))

         local fd = assert(io.open(rockspec_filename, "rb"))
         local rockspec = assert(fd:read("*a"))
         fd:close()

         assert.no.match("my_dependency", rockspec, 1, true)
         assert.no.match("config", rockspec, 1, true)

      end, finally)
   end)
end)
