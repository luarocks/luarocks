local git_repo = {}

local test_env = require("spec.util.test_env")
local lfs = require("lfs")

local files = {
----------------------------------------
["testrock-dev-1.rockspec"] = [[
package = "testrock"
version = "dev-1"
source = {
   url = "git://localhost:20000/testrock"
}
description = {
   homepage = "https://localhost",
   license = "MIT"
}
dependencies = {}
build = {
   type = "builtin",
   modules = {
      testrock = "testrock.lua"
   }
}
]],
----------------------------------------
["testrock.lua"] = [[
local testrock = {}

function testrock.say()
   return "Hello, world!"
end

return testrock
]],
----------------------------------------
["foo.c"] = [[
#include <lua.h>
int luaopen_foo(lua_State* L) {
   lua_pushnumber(L, 42);
   return 1;
}
]],
----------------------------------------
["test.lua"] = [[
print("this should be ignored!")
]],
}

local function write_file(filename, contents)
   local fd = assert(io.open(filename, "w"))
   assert(fd:write(contents))
   fd:close()
end

local function handling(args)
   local pok, ret = pcall(args.try)
   if not pok then
      pok, ret = pcall(args.catch, ret)
   end
   args.finally()
   if not pok then
      error(ret)
   end
   return ret
end

function git_repo.start()
   local dir = lfs.currentdir()
   return handling {
      try = function()
         local pidfile = os.tmpname()
         local basedir = test_env.testing_paths.testrun_dir .. "/git_repo"
         local repodir = basedir .. "/testrock"
         test_env.remove_dir(basedir)
         lfs.mkdir(basedir)
         lfs.mkdir(repodir)
         lfs.chdir(repodir)
         assert(test_env.execute("git init"))
         for name, contents in pairs(files) do
            write_file(name, contents)
            test_env.execute("git add " .. name)
         end
         assert(test_env.execute("git commit -a -m 'initial commit'"))
         assert(test_env.execute("git branch test-branch"))
         print("git daemon --reuseaddr --pid-file="..pidfile.." --base-path="..basedir.." --export-all "..repodir.." &")
         assert(test_env.execute("git daemon --reuseaddr --pid-file="..pidfile.." --base-path="..basedir.." --export-all "..repodir.." &"))
         assert(test_env.execute("sleep 0.1; netstat -ln | grep '0.0.0.0:9418 .* LISTEN'"))
         return {
            stop = function()
               local fd = io.open(pidfile)
               local pid = fd:read("*a")
               fd:close()
               assert(test_env.execute("kill -HUP " .. pid))
               test_env.remove_dir(basedir)
            end
         }
      end,
      catch = function(err)
         error(err)
      end,
      finally = function()
         lfs.chdir(dir)
      end,
   }
end

return git_repo
