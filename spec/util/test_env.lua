local test_env = {}

local lfs = require("lfs")
local versions = require("spec.util.versions")

local help_message = [[
LuaRocks test-suite

INFORMATION
   New test-suite for LuaRocks project, using unit testing framework Busted.
REQUIREMENTS
   Be sure sshd is running on your system, or use '--exclude-tags=ssh',
   to not execute tests which require sshd.
USAGE
   busted [-Xhelper <arguments>]
ARGUMENTS
   env=<type>             Set type of environment to use ("minimal" or "full",
                          default: "minimal").
   noreset                Don't reset environment after each test
   clean                  Remove existing testing environment.
   ci                     Add if running on Unix CI.
   appveyor               Add if running on Appveyor.
   os=<type>              Set OS ("linux", "osx", or "windows").
   lua_dir=<path>         Path of Lua installation (default "/usr/local")
   lua=<lua>              Name of the interpreter, may be full path (default "lua")
]]

local function help()
   print(help_message)
   os.exit(1)
end

local function title(str)
   print()
   print(("-"):rep(#str))
   print(str)
   print(("-"):rep(#str))
end

local dir_sep = package.config:sub(1, 1)
local function P(p)
   return (p:gsub("/", dir_sep))
end

local function dir_path(...)
   return P((table.concat({ ... }, "/"):gsub("\\", "/"):gsub("/+", "/")))
end

local function C(...)
   return table.concat({...}, " ")
end

--- Quote argument for shell processing. Fixes paths on Windows.
-- Adds double quotes and escapes. Based on function in fs/win32.lua.
-- @param arg string: Unquoted argument.
-- @return string: Quoted argument.
local function Q(arg)
   if test_env.TEST_TARGET_OS == "windows" then
      local drive_letter = "[%.a-zA-Z]?:?[\\/]"
      -- Quote DIR for Windows
      if arg:match("^"..drive_letter)  then
         arg = P(arg)
      end

      if arg == "\\" then
         return '\\' -- CHDIR needs special handling for root dir
      end

      return '"' .. arg .. '"'
   else
      return "'" .. arg:gsub("'", "'\\''") .. "'"
   end
end

local function V(str)
   return (str:gsub("${([^}]-)}", function(name)
      name = name:lower()
      local prefix, suffix = name:match("^(.*)_(.)$")
      if suffix then
         name = prefix
         local d = assert(versions[name])
         local v, r = d:match("^([^-]*)%-(%d*)$")
         if suffix == "d" then
            return d
         elseif suffix == "v" then
            return v
         elseif suffix == "r" then
            return r
         else
            print("Test error: invalid suffix " .. suffix .. " in variable " .. name)
            os.exit(1)
         end
      else
         if not versions[name] then
            print("Test error: no version definition for " .. name)
            os.exit(1)
         end
         return versions[name]
      end
   end))
end

local function tool(name)
   if test_env.TEST_TARGET_OS == "windows" then
      return Q(dir_path(test_env.testing_paths.win_tools, name .. ".exe"))
   else
      return name
   end
end

local os_remove = os.remove
os.remove = function(f) -- luacheck: ignore
   return os_remove(V(f))
end

local os_rename = os.rename
os.rename = function(a, b) -- luacheck: ignore
   return os_rename(V(a), V(b))
end

-- Monkeypatch incorrect tmpname's on some Lua distributions for Windows
local os_tmpname = os.tmpname
os.tmpname = function() -- luacheck:ignore
   local name = os_tmpname()
   if name:sub(1, 1) == '\\' then
      name = os.getenv "TEMP"..name
   end
   return name
end

local lfs_chdir = lfs.chdir
lfs.chdir = function(d) -- luacheck: ignore
   return lfs_chdir(V(d))
end

local lfs_attributes = lfs.attributes
lfs.attributes = function(f, ...) -- luacheck: ignore
   return lfs_attributes(V(f), ...)
end

local function exists(path)
   return lfs.attributes(path, "mode") ~= nil
end

function test_env.file_if_exists(path)
   return lfs.attributes(path, "mode") and path
end

function test_env.quiet(command)
   if not test_env.VERBOSE then
      if test_env.TEST_TARGET_OS == "windows" then
         return command .. " 1> NUL 2> NUL"
      else
         return command .. " 1> /dev/null 2> /dev/null"
      end
   else
      return command
   end
end

function test_env.copy(source, destination)
   source = V(source)
   destination = V(destination)

   local r_source, r_destination, err
   r_source, err = io.open(source, "r")
   if err then
      print(debug.traceback())
      os.exit(1)
   end

   r_destination, err = io.open(destination, "w")
   if err then
      print(debug.traceback())
      os.exit(1)
   end

   while true do
      local block = r_source:read(8192)
      if not block then break end
      r_destination:write(block)
   end

   r_source:close()
   r_destination:close()
end

function test_env.get_tmp_path()
   local path = os.tmpname()
   if test_env.TEST_TARGET_OS == "windows" and not path:find(":") then
      path = dir_path(os.getenv("TEMP"), path)
   end
   os.remove(path)
   return path
end

--- Helper function that runs the given function inside
-- a temporary directory, isolating it
-- @param f function: the function to be run
function test_env.run_in_tmp(f, finally)
   local olddir = lfs.currentdir()
   local tmpdir = test_env.get_tmp_path()
   lfs.mkdir(tmpdir)
   lfs.chdir(tmpdir)

   if not finally then
      error("run_in_tmp needs a finally argument")
   end

   -- for unit tests, so that current dir known by luarocks.fs (when running with non-lfs)
   -- is synchronized with actual lfs (system) current dir
   local fs = require("luarocks.fs")
   if not fs.change_dir then
      local cfg = require("luarocks.core.cfg")
      cfg.init()
      fs.init()
   end
   fs.change_dir(tmpdir)

   local lr_config = test_env.env_variables.LUAROCKS_CONFIG

   test_env.copy(lr_config, lr_config .. ".bak")

   finally(function()
      test_env.copy(lr_config .. ".bak", lr_config)
      lfs.chdir(olddir)
      lfs.rmdir(tmpdir)
      fs.change_dir(olddir)
   end)

   f(tmpdir)
end

--- Helper function for execute_bool and execute_output
-- @param command string: command to execute
-- @param print_command boolean: print command if 'true'
-- @param env_variables table: table of environment variables to export {FOO="bar", BAR="foo"}
-- @return final_command string: concatenated command to execution
function test_env.execute_helper(command, print_command, env_variables)
   local final_command = ""

   if print_command then
      print("[EXECUTING]: " .. command)
   end

   local unset_variables = {
      "LUA_PATH",
      "LUA_CPATH",
      "LUA_PATH_5_2",
      "LUA_CPATH_5_2",
      "LUA_PATH_5_3",
      "LUA_CPATH_5_3",
      "LUAROCKS_SYSCONFDIR",
   }

   if env_variables then
      if test_env.TEST_TARGET_OS == "windows" then
         for _, k in ipairs(unset_variables) do
            final_command = final_command .. "set " .. k .. "=&"
         end
         for k,v in pairs(env_variables) do
            final_command = final_command .. "set " .. k .. "=" .. v .. "&"
         end
         final_command = final_command:sub(1, -2) .. "&"
      else
         for _, k in ipairs(unset_variables) do
            final_command = final_command .. "unset " .. k .. "; "
         end
         final_command = final_command .. "export "
         for k,v in pairs(env_variables) do
            final_command = final_command .. k .. "='" .. v .. "' "
         end
            -- remove last space and add ';' to separate exporting variables from command
            final_command = final_command:sub(1, -2) .. "; "
      end
   end

   final_command = final_command .. command .. " 2>&1"

   return final_command
end

function test_env.execute(cmd)
   local ok = os.execute(cmd)
   return (ok == true or ok == 0) -- normalize Lua 5.1 output to boolean
end

--- Execute command and returns true/false
-- @return true/false boolean: status of the command execution
local function execute_bool(command, print_command, env_variables)
   command = test_env.execute_helper(command, print_command, env_variables)

   local redirect_filename
   local redirect = ""
   if print_command ~= nil then
      redirect_filename = dir_path(test_env.testing_paths.luarocks_tmp, "output.txt")
      redirect = " > " .. redirect_filename
      os.remove(redirect_filename)
   end
   local ok = test_env.execute(command .. redirect)
   if redirect ~= "" then
      if not ok or test_env.VERBOSE then
         local fd = io.open(redirect_filename, "r")
         if fd then
            print(fd:read("*a"))
            fd:close()
         end
      end
      os.remove(redirect_filename)
   end
   return ok
end

--- Execute command and returns output of command
-- @return output string: output the command execution
local function execute_output(command, print_command, env_variables)
   command = test_env.execute_helper(command, print_command, env_variables)

   local file = assert(io.popen(command))
   local output = file:read('*all')
   file:close()
   return (output:gsub("\r\n", "\n"):gsub("\n$", "")) -- remove final newline
end

--- Set test_env.LUA_V or test_env.LUAJIT_V based
-- on version of Lua used to run this script.
function test_env.set_lua_version()
   if _G.jit then
      test_env.LUAJIT_V = _G.jit.version:match("(2%.%d)%.%d")
      test_env.lua_version = "5.1"
   else
      test_env.LUA_V = _VERSION:match("5%.%d")
      test_env.lua_version = test_env.LUA_V
   end
end

--- Set all arguments from input into global variables
function test_env.set_args()
   -- if at least Lua/LuaJIT version argument was found on input start to parse other arguments to env. variables
   test_env.TYPE_TEST_ENV = "minimal"
   test_env.RESET_ENV = true

   for _, argument in ipairs(arg) do
      if argument:find("^env=") then
         test_env.TYPE_TEST_ENV = argument:match("^env=(.*)$")
      elseif argument == "noreset" then
         test_env.RESET_ENV = false
      elseif argument == "clean" then
         test_env.TEST_ENV_CLEAN = true
      elseif argument == "verbose" then
         test_env.VERBOSE = true
      elseif argument == "ci" then
         test_env.CI = true
      elseif argument == "appveyor" then
         test_env.APPVEYOR = true
      elseif argument:find("^os=") then
         test_env.TEST_TARGET_OS = argument:match("^os=(.*)$")
      elseif argument == "mingw" then
         test_env.MINGW = true
      elseif argument == "vs" then
         test_env.MINGW = false
      elseif argument:find("^lua_dir=") then
         test_env.LUA_DIR = argument:match("^lua_dir=(.*)$")
      elseif argument:find("^lua=") then
         test_env.LUA = argument:match("^lua=(.*)$")
      else
         help()
      end
   end

   if not test_env.TEST_TARGET_OS then
      title("OS CHECK")

      if dir_sep == "\\" then
         test_env.TEST_TARGET_OS = "windows"
         if test_env.APPVEYOR then
            test_env.OPENSSL_INCDIR = "C:\\OpenSSL-v111-Win32\\include"
            test_env.OPENSSL_LIBDIR = "C:\\OpenSSL-v111-Win32\\lib"
            if test_env.MINGW then
               test_env.OPENSSL_LIBDIR = "C:\\OpenSSL-v111-Win32\\bin"
            end
         end
      else
         local system = execute_output("uname -s")
         if system == "Linux" then
            test_env.TEST_TARGET_OS = "linux"
            if test_env.CI then
               test_env.OPENSSL_INCDIR = "/usr/include"
               test_env.OPENSSL_LIBDIR = "/usr/lib/x86_64-linux-gnu"
            end
         elseif system == "Darwin" then
            test_env.TEST_TARGET_OS = "osx"
            if test_env.CI then
               if exists("/opt/homebrew/opt/openssl@3/include") then
                  test_env.OPENSSL_INCDIR = "/opt/homebrew/opt/openssl@3/include"
                  test_env.OPENSSL_LIBDIR = "/opt/homebrew/opt/openssl@3/lib"
               elseif exists("/opt/homebrew/opt/openssl@1.1/include") then
                  test_env.OPENSSL_INCDIR = "/opt/homebrew/opt/openssl@1.1/include"
                  test_env.OPENSSL_LIBDIR = "/opt/homebrew/opt/openssl@1.1/lib"
               elseif exists("/opt/homebrew/opt/openssl/include") then
                  test_env.OPENSSL_INCDIR = "/opt/homebrew/opt/openssl/include"
                  test_env.OPENSSL_LIBDIR = "/opt/homebrew/opt/openssl/lib"
               else
                  test_env.OPENSSL_INCDIR = "/usr/local/opt/openssl/include"
                  test_env.OPENSSL_LIBDIR = "/usr/local/opt/openssl/lib"
               end
            end
         end
      end
      print(test_env.TEST_TARGET_OS)
   end

   if test_env.TEST_TARGET_OS == "windows" then
      test_env.lib_extension = "dll"
   else
      test_env.lib_extension = "so"
   end

   test_env.openssl_dirs = ""
   if test_env.OPENSSL_INCDIR then
      test_env.openssl_dirs = C("OPENSSL_INCDIR=" .. test_env.OPENSSL_INCDIR,
                                "OPENSSL_LIBDIR=" .. test_env.OPENSSL_LIBDIR)
   end

   return true
end

function test_env.copy_dir(source_path, target_path)
   source_path = V(source_path)
   target_path = V(target_path)

   local flag = test_env.TEST_TARGET_OS == "windows" and "-R" or "-a"
   os.execute(C(tool("cp"), flag, dir_path(source_path, "."), target_path))
end

--- Remove directory recursively
-- @param path string: directory path to delete
function test_env.remove_dir(path)
   path = V(path)

   if exists(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            local full_path = dir_path(path, file)

            if lfs.attributes(full_path, "mode") == "directory" then
               test_env.remove_dir(full_path)
            else
               os.remove(full_path)
            end
         end
      end
   end
   lfs.rmdir(path)
end

--- Remove subdirectories of a directory that match a pattern
-- @param path string: path to directory
-- @param pattern string: pattern matching basenames of subdirectories to be removed
function test_env.remove_subdirs(path, pattern)
   path = V(path)

   if exists(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            local full_path = dir_path(path, file)

            if lfs.attributes(full_path, "mode") == "directory" and file:find(pattern) then
               test_env.remove_dir(full_path)
            end
         end
      end
   end
end

--- Remove files matching a pattern
-- @param path string: directory where to delete files
-- @param pattern string: pattern matching basenames of files to be deleted
-- @return result_check boolean: true if one or more files deleted
function test_env.remove_files(path, pattern)
   path = V(path)

   local result_check = false
   if exists(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            if file:find(pattern) then
               if os.remove(dir_path(path, file)) then
                  result_check = true
               end
            end
         end
      end
   end
   return result_check
end


--- Function for downloading rocks and rockspecs
-- @param urls table: array of full names of rocks/rockspecs to download
-- @param save_path string: path to directory, where to download rocks/rockspecs
-- @return make_manifest boolean: true if new rocks downloaded
local function download_rocks(urls, save_path)
   local luarocks_repo = "https://luarocks.org/"

   local to_download = {}
   local fixtures = {}
   for _, url in ipairs(urls) do
      url = V(url)

      if url:match("^spec/fixtures") then
         table.insert(fixtures, P(url:gsub("^spec/fixtures", test_env.testing_paths.fixtures_dir)))
      else
         -- check if already downloaded
         if not exists(dir_path(save_path, url)) then
            table.insert(to_download, ((luarocks_repo .. url):gsub("org//", "org/")))
         end
      end
   end

   if #fixtures > 0 then
      os.execute(C(tool("cp"), table.concat(fixtures, " "), save_path))
   end

   if #to_download > 0 then
      local ok = execute_bool(C(tool("wget"), "--no-check-certificate -cP", save_path, table.concat(to_download, " ")))
      if not ok then
         os.exit(1)
      end
   end

   return (#fixtures > 0) or (#to_download > 0)
end

--- Create a file containing a string.
-- @param pathname string: path to file.
-- @param str string: content of the file.
function test_env.write_file(pathname, str, finally)
   pathname = V(pathname)

   local file = assert(io.open(pathname, "wb"))
   file:write(str)
   file:close()
   if finally then
      finally(function()
         os.remove(pathname)
      end)
   end
end

--- Create environment variables needed for tests
-- @param testing_paths table: table with paths to testing directory
-- @return env_variables table: table with created environment variables
local function create_env(testing_paths)
   local lua_v = _VERSION:gsub("Lua ", "")
   local testrun_dir = test_env.testing_paths.testrun_dir
   local lrprefix = testing_paths.testing_lrprefix
   local tree = testing_paths.testing_tree
   local sys_tree = testing_paths.testing_sys_tree
   local deps_tree = testing_paths.testing_deps_tree

   if test_env.LUAJIT_V then
      lua_v="5.1"
   end

   local env_variables = {}
   env_variables.GNUPGHOME = testing_paths.gpg_dir
   env_variables.LUA_VERSION = lua_v
   env_variables.LUAROCKS_CONFIG = dir_path(testrun_dir, "testing_config.lua")

   local lua_path = {}
   if test_env.TEST_TARGET_OS == "windows" then
      table.insert(lua_path, dir_path(lrprefix, "lua", "?.lua"))
   else
      table.insert(lua_path, dir_path(lrprefix, "share", "lua", lua_v, "?.lua"))
   end
   table.insert(lua_path, dir_path(tree,      "share", "lua", lua_v, "?.lua"))
   table.insert(lua_path, dir_path(tree,      "share", "lua", lua_v, "?", "init.lua"))
   table.insert(lua_path, dir_path(sys_tree,  "share", "lua", lua_v, "?.lua"))
   table.insert(lua_path, dir_path(sys_tree,  "share", "lua", lua_v, "?", "init.lua"))
   table.insert(lua_path, dir_path(deps_tree, "share", "lua", lua_v, "?.lua"))
   table.insert(lua_path, dir_path(deps_tree, "share", "lua", lua_v, "?", "init.lua"))
   table.insert(lua_path, dir_path(testing_paths.src_dir, "?.lua"))
   env_variables.LUA_PATH = table.concat(lua_path, ";") .. ";"

   local lua_cpath = {}
   local lib_pattern = "?." .. test_env.lib_extension
   table.insert(lua_cpath, dir_path(tree,      "lib", "lua", lua_v, lib_pattern))
   table.insert(lua_cpath, dir_path(sys_tree,  "lib", "lua", lua_v, lib_pattern))
   table.insert(lua_cpath, dir_path(deps_tree, "lib", "lua", lua_v, lib_pattern))
   env_variables.LUA_CPATH = table.concat(lua_cpath, ";") .. ";"

   local path = { os.getenv("PATH") }
   table.insert(path, dir_path(tree, "bin"))
   table.insert(path, dir_path(sys_tree, "bin"))
   table.insert(path, dir_path(deps_tree, "bin"))
   env_variables.PATH = table.concat(path, test_env.TARGET_OS == "windows" and ";" or ":")

   return env_variables
end

local function make_run_function(cmd_name, exec_function, with_coverage, do_print)
   local cmd_prefix = Q(test_env.testing_paths.lua)
   local testrun_dir = test_env.testing_paths.testrun_dir

   if with_coverage then
      cmd_prefix = C(cmd_prefix, "-e", "\"require('luacov.runner')([[" .. testrun_dir .. "/luacov.config]])\"")
   end

   if cmd_name then
      cmd_prefix = C(cmd_prefix, dir_path(test_env.testing_paths.src_dir, "bin", cmd_name))
   end

   cmd_prefix = P(cmd_prefix)

   return function(cmd, new_vars)
      cmd = V(cmd)
      local temp_vars = {}
      for k, v in pairs(test_env.env_variables) do
         temp_vars[k] = v
      end
      if new_vars then
         for k, v in pairs(new_vars) do
            temp_vars[k] = v
         end
      end
      return exec_function(C(cmd_prefix, cmd), do_print, temp_vars)
   end
end

local function make_run_functions()
   local fns = {}

   local cmds = {
      ["lua"] = nil,
      ["luarocks"] = "luarocks",
      ["luarocks_admin"] = "luarocks-admin",
   }

   for _, name in ipairs({"lua", "luarocks", "luarocks_admin"}) do
      fns[name]                     = make_run_function(cmds[name], execute_output, true, true)
      fns[name .. "_bool"]          = make_run_function(cmds[name], execute_bool,   true, true)
      fns[name .. "_nocov"]         = make_run_function(cmds[name], execute_bool,   false, true)
      fns[name .. "_noprint_nocov"] = make_run_function(cmds[name], execute_bool,   false, false)
   end

   return fns
end

local function move_file(src, dst)
   local ok = execute_bool(C(tool("mv"), P(src), P(dst)))
   if not ok then
      print(debug.traceback())
      os.exit(1)
   end
end

--- Rebuild environment.
-- Remove old installed rocks and install new ones,
-- updating manifests and tree copies.
local function build_environment(rocks, env_variables)
   title("BUILDING ENVIRONMENT")
   local testing_paths = test_env.testing_paths
   test_env.remove_dir(testing_paths.testing_tree)
   test_env.remove_dir(testing_paths.testing_sys_tree)

   lfs.mkdir(testing_paths.testing_tree)
   lfs.mkdir(testing_paths.testing_sys_tree)
   lfs.mkdir(testing_paths.testing_deps_tree)

   test_env.run.luarocks_admin_nocov(C("make_manifest", Q(testing_paths.testing_server)))
   test_env.run.luarocks_admin_nocov(C("make_manifest", Q(testing_paths.testing_cache)))

   for _, rock in ipairs(rocks) do
      local only_server = "--only-server=" .. testing_paths.testing_cache
      local tree = "--tree=" .. testing_paths.testing_deps_tree
      if not test_env.run.luarocks_nocov(test_env.quiet(C("install", only_server, tree, Q(rock)), env_variables)) then
         assert(test_env.run.luarocks_nocov(C("build", tree, Q(rock)), env_variables))
         assert(test_env.run.luarocks_nocov(C("pack", tree, Q(rock)), env_variables))
         move_file(rock .. "-*.rock", testing_paths.testing_cache)
      end
   end
end

local function find_lua()
   -- (1) LUA is a full path
   if test_env.LUA and test_env.LUA:match("[/\\]") then

      local lua_bindir = test_env.LUA:match("^(.-)[/\\][^/\\]*$")
      local luadir = test_env.LUA_DIR or lua_bindir:gsub("[/\\]bin$")
      local lua = test_env.LUA

      return lua_bindir, luadir, lua
   end

   -- (2) LUA is just the interpreter name
   local lua_exe = test_env.LUA
                   or ((test_env.TEST_TARGET_OS == "windows") and "lua.exe")
                   or "lua"

   -- (2.1) LUA_DIR was given
   if test_env.LUA_DIR then

      local luadir = test_env.LUA_DIR
      local lua_bindir = exists(dir_path(luadir, "bin"))
                   and dir_path(luadir, "bin")
                   or luadir
      local lua = dir_path(lua_bindir, lua_exe)

      return lua_bindir, luadir, lua
   end

   -- (2.2) LUA_DIR was not given, try some default paths
   local try_dirs = (test_env.TEST_TARGET_OS == "windows")
                    and { os.getenv("ProgramFiles(x86)").."\\LuaRocks" }
                    or  { "/usr/local", "/usr" }

   for _, luadir in ipairs(try_dirs) do
      for _, lua_bindir in ipairs({ luadir, dir_path(luadir, "bin") }) do
         local lua = dir_path(lua_bindir, lua_exe)
         if exists(lua) then
            return lua_bindir, luadir, lua
         end
      end
   end
end

local function create_testing_paths(suffix)
   local paths = {}

   paths.lua_bindir, paths.luadir, paths.lua = find_lua()
   if (not paths.lua) or (not exists(paths.lua)) then
      error("Lua interpreter not found! Run `busted -Xhelper help` for options")
   end

   local base_dir = lfs.currentdir()
   paths.src_dir           = dir_path(base_dir, "src")
   paths.spec_dir          = dir_path(base_dir, "spec")
   paths.util_dir          = dir_path(base_dir, "spec", "util")
   paths.fixtures_dir      = dir_path(base_dir, "spec", "fixtures")
   paths.fixtures_repo_dir = dir_path(base_dir, "spec", "fixtures", "a_repo")
   paths.gpg_dir           = dir_path(base_dir, "spec", "fixtures", "gpg")

   local testrun_dir = dir_path(base_dir, "testrun")
   paths.testrun_dir           = testrun_dir
   paths.testing_lrprefix      = dir_path(testrun_dir, "testing_lrprefix-" .. suffix)
   paths.testing_tree          = dir_path(testrun_dir, "testing-" .. suffix)
   paths.testing_sys_tree      = dir_path(testrun_dir, "testing_sys-" .. suffix)
   paths.testing_deps_tree     = dir_path(testrun_dir, "testing_deps-" .. suffix)
   paths.testing_cache         = dir_path(testrun_dir, "testing_cache-" .. suffix)
   paths.testing_server        = dir_path(testrun_dir, "testing_server-" .. suffix)

   local rocks_v = "rocks-" .. test_env.lua_version
   paths.testing_rocks      = dir_path(paths.testing_tree,      "lib", "luarocks", rocks_v)
   paths.testing_sys_rocks  = dir_path(paths.testing_sys_tree,  "lib", "luarocks", rocks_v)
   paths.testing_deps_rocks = dir_path(paths.testing_deps_tree, "lib", "luarocks", rocks_v)

   if test_env.TEST_TARGET_OS == "windows" then
      paths.luarocks_tmp = os.getenv("TEMP")
   else
      paths.luarocks_tmp = "/tmp/luarocks_testing"
   end

   if test_env.TEST_TARGET_OS == "windows" then
      paths.win_tools = dir_path(base_dir, "win32", "tools")
   end

   return paths
end

--- Helper function to unload luarocks modules from global table package.loaded
-- Needed to load our local (testing) version of LuaRocks
function test_env.unload_luarocks()
   for modname, _ in pairs(package.loaded) do
      if modname:match("^luarocks%.") then
         package.loaded[modname] = nil
      end
   end
   local src_pattern = dir_path(test_env.testing_paths.src_dir, "?.lua")
   if not package.path:find(src_pattern, 1, true) then
      package.path = src_pattern .. ";" .. package.path
   end
end

local function get_luarocks_platform(variables)
   local print_arch_script = "\"" ..
                             "cfg = require('luarocks.core.cfg');" ..
                             "cfg.init();" ..
                             "print(cfg.arch)" ..
                             "\""
   local cmd = C(test_env.testing_paths.lua, "-e", print_arch_script)
   return execute_output(cmd, false, variables)
end

--- Test if required rock is installed and if not, install it.
-- Return `true` if the rock is already installed or has been installed successfully,
-- `false` if installation failed.
function test_env.need_rock(rock)
   rock = V(rock)

   print("Check if " .. rock .. " is installed")
   if test_env.run.luarocks_noprint_nocov(test_env.quiet("show " .. rock)) then
      return true
   else
      local ok = test_env.run.luarocks_noprint_nocov(test_env.quiet("install " .. rock))
      if not ok then
         print("WARNING: failed installing " .. rock)
      end
      return ok
   end
end

--- For each key-value pair in replacements table
-- replace %{key} in given string with value.
local function substitute(str, replacements)
   return (str:gsub("%%%b{}", function(marker)
      local r = replacements[marker:sub(3, -2)]
      if r then
         r = r:gsub("\\", "\\\\")
      end
      return r
   end))
end


--- Create configs for luacov and several versions of Luarocks
-- configs needed for some tests.
local function create_configs()
   local testrun_dir = test_env.testing_paths.testrun_dir

   -- testing_config.lua
   -- testing_config_show_downloads.lua
   -- testing_config_no_downloader.lua
   local config_content = substitute([[
      rocks_trees = {
         { name = "user", root = "%{testing_tree}" },
         { name = "deps", root = "%{testing_deps_tree}" },
         { name = "system", root = "%{testing_sys_tree}" },
      }
      rocks_servers = {
         "%{testing_server}"
      }
      local_cache = "%{testing_cache}"
      upload_server = "testing"
      upload_user = "%{user}"
      upload_servers = {
         testing = {
            rsync = "localhost/tmp/luarocks_testing",
         },
      }
   ]], {
      user = "testuser",
      testing_sys_tree = test_env.testing_paths.testing_sys_tree,
      testing_deps_tree = test_env.testing_paths.testing_deps_tree,
      testing_tree = test_env.testing_paths.testing_tree,
      testing_server = test_env.testing_paths.testing_server,
      testing_cache = test_env.testing_paths.testing_cache
   })

   test_env.write_file(dir_path(testrun_dir, "testing_config.lua"), config_content .. " \nweb_browser = \"true\"")
   test_env.write_file(dir_path(testrun_dir, "testing_config_show_downloads.lua"), config_content
                  .. "show_downloads = true \n rocks_servers={\"http://luarocks.org/repositories/rocks\"}")
   test_env.write_file(dir_path(testrun_dir, "testing_config_no_downloader.lua"), config_content
                  .. "variables = { WGET = 'invalid', CURL = 'invalid' }")

   -- testing_config_sftp.lua
   config_content = substitute([[
      rocks_trees = {
         "%{testing_tree}",
         "%{testing_deps_tree}",
         "%{testing_sys_tree}",
      }
      local_cache = "%{testing_cache}"
      upload_server = "testing"
      upload_user = "%{user}"
      upload_servers = {
         testing = {
            sftp = "localhost/tmp/luarocks_testing",
         },
      }
   ]], {
      user = "testuser",
      testing_sys_tree = test_env.testing_paths.testing_sys_tree,
      testing_deps_tree = test_env.testing_paths.testing_deps_tree,
      testing_tree = test_env.testing_paths.testing_tree,
      testing_cache = test_env.testing_paths.testing_cache
   })

   test_env.write_file(dir_path(testrun_dir, "testing_config_sftp.lua"), config_content)

   -- luacov.config
   config_content = substitute([[
      return {
         statsfile = "%{statsfile}",
         reportfile = "%{reportfile}",
         exclude = {
            "src%/luarocks%/vendor.+$",
         },
         modules = {
            ["luarocks"] = "%{luarocks_path}",
            ["luarocks-admin"] = "%{luarocks_admin_path}",
            ["luarocks.*"] = "src",
            ["luarocks.*.*"] = "src",
            ["luarocks.*.*.*"] = "src"
         }
      }
   ]], {
      statsfile = dir_path(testrun_dir, "luacov.stats.out"),
      reportfile = dir_path(testrun_dir, "luacov.report.out"),
      luarocks_path = dir_path("src", "bin", "luarocks"),
      luarocks_admin_path = dir_path("src", "bin", "luarocks-admin"),
   })

   test_env.write_file(dir_path(testrun_dir, "luacov.config"), config_content)

   config_content = [[
      -- Config file of mock LuaRocks.org site for tests
      upload = {
         server = "http://localhost:8080",
         tool_version = "1.0.0",
         api_version = "1",
      }
   ]]
   test_env.write_file(dir_path(testrun_dir, "luarocks_site.lua"), config_content)
end

--- Remove testing directories.
local function clean()
   local testrun_dir = test_env.testing_paths.testrun_dir

   print("Cleaning testing directory...")
   test_env.remove_dir(test_env.testing_paths.luarocks_tmp)
   test_env.remove_subdirs(testrun_dir, "testing[_%-]")
   test_env.remove_files(testrun_dir, "testing_")
   test_env.remove_files(testrun_dir, "luacov")
   test_env.remove_files(testrun_dir, "upload_config")
   test_env.remove_files(testrun_dir, "luarocks_site")
   print("Cleaning done!")
end

--- Setup current checkout of luarocks to work with testing prefix.
local function setup_luarocks()
   local testing_paths = test_env.testing_paths
   title("Setting up LuaRocks")

   local lines = {
      "return {",
      ("SYSCONFDIR = %q,"):format(dir_path(testing_paths.testing_lrprefix, "etc/luarocks")),
      ("LUA_DIR = %q,"):format(testing_paths.luadir),
      ("LUA_BINDIR = %q,"):format(testing_paths.lua_bindir),
      ("LUA = %q,"):format(testing_paths.lua),
   }

   if test_env.TEST_TARGET_OS == "windows" then
      if test_env.MINGW then
         table.insert(lines, [[SYSTEM = "mingw",]])
      else
         table.insert(lines, [[SYSTEM = "windows",]])
      end
      table.insert(lines, ("WIN_TOOLS = %q,"):format(testing_paths.win_tools))
   end

   table.insert(lines, "}")

   test_env.write_file("src/luarocks/core/hardcoded.lua", table.concat(lines, "\n") .. "\n")

   print("LuaRocks set up correctly!")
end

local function mock_api_call(path)
   return test_env.execute(C(tool("wget"), "--timeout=0.1 --quiet --tries=10 http://localhost:8080" .. path))
end

function test_env.mock_server_init()
   if not test_env.mock_prepared then
      error("need to setup_specs with with_mock set to true")
   end

   local testing_paths = test_env.testing_paths
   assert(test_env.need_rock("restserver-xavante"))

   local lua = Q(testing_paths.lua)
   local mock_server = Q(dir_path(testing_paths.util_dir, "mock-server.lua"))
   local fixtures_dir = Q(testing_paths.fixtures_dir)

   local cmd = C(lua, mock_server, fixtures_dir)

   local bg_cmd = test_env.TEST_TARGET_OS == "windows"
                  and C("start", "/b", "\"\"", cmd)
                  or  C(cmd, "&")

   os.execute(test_env.execute_helper(bg_cmd, true, test_env.env_variables))

   for _ = 1, 100 do
      if mock_api_call("/api/tool_version") then
         break
      end
      os.execute(test_env.TEST_TARGET_OS == "windows"
                 and "ping 192.0.2.0 -n 1 -w 250 > NUL"
                 or  "sleep 0.1")
   end

end

function test_env.mock_server_done()
   mock_api_call("/shutdown")
end

local function find_binary_rock(src_rock, dirname)
   local patt = src_rock:gsub("([.-])", "%%%1"):gsub("src", ".*[^s][^r][^c]")
   for name in lfs.dir(dirname) do
      if name:match(patt) then
         return true
      end
   end
   return false
end

local function prepare_mock_server_binary_rocks()
   if test_env.mock_prepared then
      return
   end

   local testing_paths = test_env.testing_paths

   local rocks = {
      -- rocks needed for mock-server
      "luasocket-${LUASOCKET}.src.rock",
      "coxpcall-1.16.0-1.src.rock",
      "binaryheap-${BINARYHEAP}.src.rock",
      "timerwheel-${TIMERWHEEL}.src.rock",
      "copas-${COPAS}.src.rock",
      "luafilesystem-${LUAFILESYSTEM}.src.rock",
      "xavante-2.4.0-1.src.rock",
      "wsapi-1.6.1-1.src.rock",
      "rings-1.3.0-1.src.rock",
      "wsapi-xavante-1.6.1-1.src.rock",
      "dkjson-${DKJSON}.src.rock",
      "restserver-0.1-1.src.rock",
      "restserver-xavante-0.2-1.src.rock",
   }
   local make_manifest = download_rocks(rocks, testing_paths.testing_server)
   for _, rock in ipairs(rocks) do
      rock = V(rock)
      local rockname = rock:gsub("%-[^-]+%-%d+%.[%a.]+$", "")
      if not find_binary_rock(rock, testing_paths.testing_server) then
         local rockpath = dir_path(testing_paths.testing_server, rock)
         local tree = "--tree=" .. testing_paths.testing_cache

         test_env.run.luarocks_nocov(C("build", Q(rockpath), tree))
         test_env.run.luarocks_nocov(C("pack", rockname, tree))

         move_file(rockname .. "-*.rock", testing_paths.testing_server)
         make_manifest = true
      end
   end
   if make_manifest then
      test_env.run.luarocks_admin_nocov(C("make_manifest", Q(testing_paths.testing_server)))
   end

   test_env.mock_prepared = true
end

---
-- Main function to create config files and testing environment
function test_env.main()
   local testing_paths = test_env.testing_paths
   local testrun_dir = test_env.testing_paths.testrun_dir

   if test_env.TEST_ENV_CLEAN then
      clean()
   end

   lfs.mkdir(testrun_dir)
   test_env.write_file(dir_path(testrun_dir, ".luarocks-no-project"), "")
   lfs.mkdir(testing_paths.testing_cache)
   lfs.mkdir(testing_paths.luarocks_tmp)

   create_configs()

   setup_luarocks()

   -- Preparation of rocks for building environment
   local rocks = {} -- names of rocks, required for building environment
   local urls = {}  -- names of rock and rockspec files to be downloaded

   local env_vars = {
      LUAROCKS_CONFIG = dir_path(testrun_dir, "testing_config.lua")
   }

   if test_env.TYPE_TEST_ENV == "full" then
      table.insert(urls, "/luafilesystem-${LUAFILESYSTEM}.src.rock")
      table.insert(urls, "/luasocket-${LUASOCKET}.src.rock")
      table.insert(urls, "/luasec-${LUASEC}.src.rock")
      table.insert(urls, "/md5-1.2-1.src.rock")
      table.insert(urls, "/manifests/hisham/lua-zlib-1.2-0.src.rock")
      table.insert(urls, "/manifests/hisham/lua-bz2-0.2.1.1-1.src.rock")
      rocks = {"luafilesystem", "luasocket", "luasec", "md5", "lua-zlib", "lua-bz2"}
      if test_env.TEST_TARGET_OS ~= "windows" then
         if test_env.lua_version == "5.1" then
            table.insert(urls, "/bit32-${BIT32}.src.rock")
            table.insert(rocks, "bit32")
         end
         table.insert(urls, "/luaposix-${LUAPOSIX}.src.rock")
         table.insert(rocks, "luaposix")
      end
      assert(test_env.run.luarocks_nocov(C("config", "variables.OPENSSL_INCDIR", Q(test_env.OPENSSL_INCDIR)), env_vars))
      assert(test_env.run.luarocks_nocov(C("config", "variables.OPENSSL_LIBDIR", Q(test_env.OPENSSL_LIBDIR)), env_vars))
   end

   -- luacov is needed for both minimal or full environment
   table.insert(urls, "/luacov-${LUACOV}.src.rock")
   table.insert(urls, "/cluacov-${CLUACOV}.src.rock")
   table.insert(rocks, "luacov")
   table.insert(rocks, "cluacov")

   -- Download rocks needed for LuaRocks testing environment
   lfs.mkdir(testing_paths.testing_server)
   download_rocks(urls, testing_paths.testing_server)

   build_environment(rocks, env_vars)
end

--- Function for initial setup of environment and variables
function test_env.setup_specs(extra_rocks, use_mock)
   test_env.unload_luarocks()

   local testrun_dir = test_env.testing_paths.testrun_dir
   local variables = test_env.env_variables

   -- if global variable about successful creation of testing environment doesn't exist, build environment
   if not test_env.setup_done then
      if test_env.CI then
         if not exists(os.getenv("HOME"), ".ssh/id_rsa.pub") then
            execute_bool("ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa")
            execute_bool("cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys")
            execute_bool("chmod og-wx ~/.ssh/authorized_keys")
            execute_bool("ssh-keyscan localhost >> ~/.ssh/known_hosts")
         end
      end

      test_env.main()

      -- preload before meddling with package.path
      require("spec.util.git_repo")
      require("spec.util.quick")

      package.path = variables.LUA_PATH
      package.cpath = variables.LUA_CPATH

      test_env.platform = get_luarocks_platform(test_env.env_variables)
      test_env.wrapper_extension = test_env.TEST_TARGET_OS == "windows" and ".bat" or ""
      test_env.setup_done = true
      title("RUNNING TESTS")
   end

   if use_mock == "mock" then
      prepare_mock_server_binary_rocks()
   end

   if extra_rocks then
      local make_manifest = download_rocks(extra_rocks, test_env.testing_paths.testing_server)
      if make_manifest then
         test_env.run.luarocks_admin_nocov("make_manifest " .. test_env.testing_paths.testing_server)
      end
   end

   if test_env.RESET_ENV then
      test_env.remove_dir(test_env.testing_paths.testing_tree)
      test_env.remove_dir(test_env.testing_paths.testing_sys_tree)
   end

   lfs.chdir(testrun_dir)
end

test_env.set_lua_version()
test_env.set_args()
test_env.testing_paths = create_testing_paths(test_env.LUA_V or test_env.LUAJIT_V)
test_env.env_variables = create_env(test_env.testing_paths)
test_env.run = make_run_functions()
test_env.exists = exists
test_env.V = V
test_env.Q = Q
test_env.P = P
test_env.platform = get_luarocks_platform(test_env.env_variables)

return test_env
