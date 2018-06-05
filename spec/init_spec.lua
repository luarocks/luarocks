local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths
local get_tmp_path = test_env.get_tmp_path
local copy_dir = test_env.copy_dir
local is_win = test_env.TEST_TARGET_OS == "windows"

test_env.unload_luarocks()

describe("Luarocks init test #integration", function()
   local tmpdir
   
   after_each(function()
      if tmpdir then
         lfs.rmdir(tmpdir)
         tmpdir = nil
      end
   end)
   
   it("LuaRocks init with no arguments", function()
      tmpdir = get_tmp_path()
      lfs.mkdir(tmpdir)
      local myproject = tmpdir .. "/myproject"
      lfs.mkdir(myproject)
      local olddir = lfs.currentdir()
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
      
      lfs.chdir(olddir)
   end)
   
   it("LuaRocks init with given arguments", function()
      tmpdir = get_tmp_path()
      lfs.mkdir(tmpdir)
      local myproject = tmpdir .. "/myproject"
      lfs.mkdir(myproject)
      local olddir = lfs.currentdir()
      lfs.chdir(myproject)
      
      assert(run.luarocks("init customname 1.0"))
      assert.truthy(lfs.attributes(myproject .. "/customname-1.0-1.rockspec"))
      
      lfs.chdir(olddir)
   end)
   
   it("LuaRocks init in a git repo", function()
      tmpdir = get_tmp_path()
      lfs.mkdir(tmpdir)
      local olddir = lfs.currentdir()
      lfs.chdir(tmpdir)
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
      
      lfs.chdir(olddir)
   end)
end)
