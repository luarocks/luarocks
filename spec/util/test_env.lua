local test_env = {}

local lfs = require("lfs")

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
   travis                 Add if running on TravisCI.
   appveyor               Add if running on Appveyor.
   os=<type>              Set OS ("linux", "osx", or "windows").
   lua_dir=<path>         Path of Lua installation (default "/usr/local")
   lua_interpreter=<lua>  Name of the interpreter (default "lua")
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

function test_env.exists(path)
   return lfs.attributes(path, "mode") ~= nil
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
         arg = arg:gsub("/", "\\")
      end
      
      if arg == "\\" then
         return '\\' -- CHDIR needs special handling for root dir
      end

      return '"' .. arg .. '"'
   else
      return "'" .. arg:gsub("'", "'\\''") .. "'"
   end
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
   local r_source, err = io.open(source, "r")
   local r_destination, err = io.open(destination, "w")

   while true do
      local block = r_source:read(8192)
      if not block then break end
      r_destination:write(block)
   end

   r_source:close()
   r_destination:close()
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
      redirect_filename = test_env.testing_paths.luarocks_tmp.."/output.txt"
      redirect = " > "..redirect_filename
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
   test_env.OPENSSL_DIRS = ""
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
      elseif argument == "travis" then
         test_env.TRAVIS = true
      elseif argument == "appveyor" then
         test_env.APPVEYOR = true
         test_env.OPENSSL_DIRS = "OPENSSL_LIBDIR=C:\\OpenSSL-Win32\\lib OPENSSL_INCDIR=C:\\OpenSSL-Win32\\include"
      elseif argument:find("^os=") then
         test_env.TEST_TARGET_OS = argument:match("^os=(.*)$")
      elseif argument == "mingw" then
         test_env.MINGW = true
      elseif argument == "vs" then
         test_env.MINGW = false
      elseif argument:find("^lua_dir=") then
         test_env.LUA_DIR = argument:match("^lua_dir=(.*)$")
      elseif argument:find("^lua_interpreter=") then
         test_env.LUA_INTERPRETER = argument:match("^lua_interpreter=(.*)$")
      else
         help()
      end
   end

   if not test_env.TEST_TARGET_OS then
      title("OS CHECK")

      if package.config:sub(1,1) == "\\" then
         test_env.TEST_TARGET_OS = "windows"
      else
         local system = execute_output("uname -s")
         if system == "Linux" then
            test_env.TEST_TARGET_OS = "linux"
         elseif system == "Darwin" then
            test_env.TEST_TARGET_OS = "osx"
            if test_env.TRAVIS then
               test_env.OPENSSL_DIRS = "OPENSSL_LIBDIR=/usr/local/opt/openssl/lib OPENSSL_INCDIR=/usr/local/opt/openssl/include"
            end
         end
      end
   end
   return true
end

function test_env.copy_dir(source_path, target_path)
   local testing_paths = test_env.testing_paths
   if test_env.TEST_TARGET_OS == "windows" then
      execute_bool(testing_paths.win_tools .. "/cp -R ".. source_path .. "/. " .. target_path)
   else
      execute_bool("cp -a ".. source_path .. "/. " .. target_path)
   end
end

--- Remove directory recursively
-- @param path string: directory path to delete
function test_env.remove_dir(path)
   if test_env.exists(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            local full_path = path..'/'..file

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
   if test_env.exists(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            local full_path = path..'/'..file

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
   local result_check = false
   if test_env.exists(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            if file:find(pattern) then
               if os.remove(path .. "/" .. file) then
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
   local luarocks_repo = "https://luarocks.org"
   local make_manifest = false

   for _, url in ipairs(urls) do
      -- check if already downloaded
      if not test_env.exists(save_path .. url) then
         if test_env.TEST_TARGET_OS == "windows" then
            execute_bool(test_env.testing_paths.win_tools .. "/wget -cP " .. save_path .. " " .. luarocks_repo .. url .. " --no-check-certificate")
         else
            execute_bool("wget -cP " .. save_path .. " " .. luarocks_repo .. url)
         end
         make_manifest = true 
      end
   end
   return make_manifest
end

--- Create a file containing a string.
-- @param path string: path to file.
-- @param str string: content of the file.
local function write_file(path, str)
   local file = assert(io.open(path, "w"))
   file:write(str)
   file:close()
end

--- Create md5sum of directory structure recursively, based on filename and size
-- @param path string: path to directory for generate md5sum
-- @return md5sum string: md5sum of directory
local function hash_environment(path)
   if test_env.TEST_TARGET_OS == "linux" then
      return execute_output("cd " .. path .. " && find . -printf \"%s %p\n\"")
   elseif test_env.TEST_TARGET_OS == "osx" then
      return execute_output("find " .. path .. " -type f -exec stat -f \"%z %N\" {} \\; | md5")
   elseif test_env.TEST_TARGET_OS == "windows" then
      return execute_output("\"" .. Q(test_env.testing_paths.win_tools .. "/find") .. " " .. Q(path)
         .. " -printf \"%s %p\"\" > temp_sum.txt && certUtil -hashfile temp_sum.txt && del temp_sum.txt")
   end
end

--- Create environment variables needed for tests
-- @param testing_paths table: table with paths to testing directory
-- @return env_variables table: table with created environment variables
local function create_env(testing_paths)
   local luaversion_short = _VERSION:gsub("Lua ", "")
   
   if test_env.LUAJIT_V then
      luaversion_short="5.1"
   end
   
   local env_variables = {}
   env_variables.LUA_VERSION = luaversion_short
   env_variables.LUAROCKS_CONFIG = testing_paths.testrun_dir .. "/testing_config.lua"
   if test_env.TEST_TARGET_OS == "windows" then
      env_variables.LUA_PATH = testing_paths.testing_lrprefix .. "\\lua\\?.lua;"
   else
      env_variables.LUA_PATH = testing_paths.testing_lrprefix .. "/share/lua/" .. luaversion_short .. "/?.lua;"
   end
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_sys_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_sys_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.src_dir .. "/?.lua;"
   env_variables.LUA_CPATH = testing_paths.testing_tree .. "/lib/lua/" .. luaversion_short .. "/?.so;"
                           .. testing_paths.testing_sys_tree .. "/lib/lua/" .. luaversion_short .. "/?.so;"
   env_variables.PATH = os.getenv("PATH") .. ";" .. testing_paths.testing_tree .. "/bin;" .. testing_paths.testing_sys_tree .. "/bin;"

   return env_variables
end

--- Create md5sums of origin system and system-copy testing directory
-- @param testing_paths table: table with paths to testing directory
-- @return md5sums table: table of md5sums of system and system-copy testing directory
local function create_md5sums(testing_paths)
   local md5sums = {}
   md5sums.testing_tree_copy_md5 = hash_environment(testing_paths.testing_tree_copy)
   md5sums.testing_sys_tree_copy_md5 = hash_environment(testing_paths.testing_sys_tree_copy)

   return md5sums
end

local function make_run_function(cmd_name, exec_function, with_coverage, do_print)
   local cmd_prefix = Q(test_env.testing_paths.lua) .. " "

   if with_coverage then
      cmd_prefix = cmd_prefix .. "-e \"require('luacov.runner')('" .. test_env.testing_paths.testrun_dir .. "/luacov.config')\" "
   end
   
   if test_env.TEST_TARGET_OS == "windows" then
      cmd_prefix = cmd_prefix .. Q(test_env.testing_paths.testing_lrprefix .. "/" .. cmd_name .. ".lua") .. " "
   else
      cmd_prefix = cmd_prefix .. test_env.testing_paths.src_dir .. "/bin/" .. cmd_name .. " "
   end

   return function(cmd, new_vars)
      local temp_vars = {}
      for k, v in pairs(test_env.env_variables) do
         temp_vars[k] = v
      end
      if new_vars then
         for k, v in pairs(new_vars) do
            temp_vars[k] = v
         end
      end
      return exec_function(cmd_prefix .. cmd, do_print, temp_vars)
   end
end

local function make_run_functions()
   return {
      luarocks = make_run_function("luarocks", execute_output, true, true),
      luarocks_bool = make_run_function("luarocks", execute_bool, true, true),
      luarocks_noprint = make_run_function("luarocks", execute_bool, true, false),
      luarocks_nocov = make_run_function("luarocks", execute_bool, false, true),
      luarocks_noprint_nocov = make_run_function("luarocks", execute_bool, false, false),
      luarocks_admin = make_run_function("luarocks-admin", execute_output, true, true),
      luarocks_admin_bool = make_run_function("luarocks-admin", execute_bool, true, true),
      luarocks_admin_nocov = make_run_function("luarocks-admin", execute_bool, false, false)
   }
end

--- Rebuild environment.
-- Remove old installed rocks and install new ones,
-- updating manifests and tree copies.
local function build_environment(rocks, env_variables)
   title("BUILDING ENVIRONMENT")
   local testing_paths = test_env.testing_paths
   test_env.remove_dir(testing_paths.testing_tree)
   test_env.remove_dir(testing_paths.testing_sys_tree)
   test_env.remove_dir(testing_paths.testing_tree_copy)
   test_env.remove_dir(testing_paths.testing_sys_tree_copy)

   lfs.mkdir(testing_paths.testing_tree)
   lfs.mkdir(testing_paths.testing_sys_tree)

   test_env.run.luarocks_admin_nocov("make_manifest " .. Q(testing_paths.testing_server))
   test_env.run.luarocks_admin_nocov("make_manifest " .. Q(testing_paths.testing_cache))

   for _, rock in ipairs(rocks) do
      if not test_env.run.luarocks_nocov("install --only-server=" .. testing_paths.testing_cache .. " --tree=" .. testing_paths.testing_sys_tree .. " " .. Q(rock), env_variables) then
         test_env.run.luarocks_nocov("build --tree=" .. Q(testing_paths.testing_sys_tree) .. " " .. Q(rock) .. "", env_variables)
         test_env.run.luarocks_nocov("pack --tree=" .. Q(testing_paths.testing_sys_tree) .. " " .. Q(rock), env_variables)
         if test_env.TEST_TARGET_OS == "windows" then
            execute_bool(testing_paths.win_tools .. "/mv " .. rock .. "-*.rock " .. testing_paths.testing_cache)
         else
            execute_bool("mv " .. rock .. "-*.rock " .. testing_paths.testing_cache)
         end
      end
   end
   
   test_env.copy_dir(testing_paths.testing_tree, testing_paths.testing_tree_copy)
   test_env.copy_dir(testing_paths.testing_sys_tree, testing_paths.testing_sys_tree_copy)
end

--- Reset testing environment
local function reset_environment(testing_paths, md5sums)
   local testing_tree_md5 = hash_environment(testing_paths.testing_tree)
   local testing_sys_tree_md5 = hash_environment(testing_paths.testing_sys_tree)

   if testing_tree_md5 ~= md5sums.testing_tree_copy_md5 then
      test_env.remove_dir(testing_paths.testing_tree)
      test_env.copy_dir(testing_paths.testing_tree_copy, testing_paths.testing_tree)
   end

   if testing_sys_tree_md5 ~= md5sums.testing_sys_tree_copy_md5 then
      test_env.remove_dir(testing_paths.testing_sys_tree)
      test_env.copy_dir(testing_paths.testing_sys_tree_copy, testing_paths.testing_sys_tree)
   end
end

local function create_paths(luaversion_full)

   local testing_paths = {}
   testing_paths.luadir = (test_env.LUA_DIR or "/usr/local")
   testing_paths.lua = testing_paths.luadir .. "/bin/" .. (test_env.LUA_INTERPRETER or "lua")

   if test_env.TEST_TARGET_OS == "windows" then
      testing_paths.luarocks_tmp = os.getenv("TEMP")
   else
      testing_paths.luarocks_tmp = "/tmp/luarocks_testing"
   end

   local base_dir = lfs.currentdir()

   if test_env.TEST_TARGET_OS == "windows" then
      base_dir = base_dir:gsub("\\","/")
   end

   testing_paths.fixtures_dir = base_dir .. "/spec/fixtures"
   testing_paths.util_dir = base_dir .. "/spec/util"
   testing_paths.testrun_dir = base_dir .. "/testrun"
   testing_paths.src_dir = base_dir .. "/src"
   testing_paths.testing_lrprefix = testing_paths.testrun_dir .. "/testing_lrprefix-" .. luaversion_full
   testing_paths.testing_tree = testing_paths.testrun_dir .. "/testing-" .. luaversion_full
   testing_paths.testing_tree_copy = testing_paths.testrun_dir .. "/testing_copy-" .. luaversion_full
   testing_paths.testing_sys_tree = testing_paths.testrun_dir .. "/testing_sys-" .. luaversion_full
   testing_paths.testing_sys_tree_copy = testing_paths.testrun_dir .. "/testing_sys_copy-" .. luaversion_full
   testing_paths.testing_cache = testing_paths.testrun_dir .. "/testing_cache-" .. luaversion_full
   testing_paths.testing_server = testing_paths.testrun_dir .. "/testing_server-" .. luaversion_full

   testing_paths.testing_rocks = testing_paths.testing_tree .. "/lib/luarocks/rocks-" .. test_env.lua_version
   testing_paths.testing_sys_rocks = testing_paths.testing_sys_tree .. "/lib/luarocks/rocks-" .. test_env.lua_version

   if test_env.TEST_TARGET_OS == "windows" then
      testing_paths.win_tools = testing_paths.testing_lrprefix .. "/tools"
   end

   return testing_paths
end

--- Helper function to unload luarocks modules from global table package.loaded
-- Needed to load our local (testing) version of LuaRocks
function test_env.unload_luarocks()
   for modname, _ in pairs(package.loaded) do
      if modname:match("^luarocks%.") then
         package.loaded[modname] = nil
      end
   end
   local src_pattern = test_env.testing_paths.src_dir .. "/?.lua"
   if not package.path:find(src_pattern, 1, true) then
      package.path = src_pattern .. ";" .. package.path
   end
end

--- Function for initial setup of environment, variables, md5sums for spec files
function test_env.setup_specs(extra_rocks)
   -- if global variable about successful creation of testing environment doesn't exist, build environment
   if not test_env.setup_done then
      if test_env.TRAVIS then
         if not test_env.exists(os.getenv("HOME") .. "/.ssh/id_rsa.pub") then
            execute_bool("ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa")
            execute_bool("cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys")
            execute_bool("chmod og-wx ~/.ssh/authorized_keys")
            execute_bool("ssh-keyscan localhost >> ~/.ssh/known_hosts")
         end
      end

      test_env.main()
      
      -- preload before meddling with package.path
      require("spec.util.git_repo")

      package.path = test_env.env_variables.LUA_PATH

      test_env.platform = execute_output(test_env.testing_paths.lua .. " -e \"print(require('luarocks.core.cfg').arch)\"", false, test_env.env_variables)
      test_env.lib_extension = execute_output(test_env.testing_paths.lua .. " -e \"print(require('luarocks.core.cfg').lib_extension)\"", false, test_env.env_variables)
      test_env.wrapper_extension = test_env.TEST_TARGET_OS == "windows" and ".bat" or ""
      test_env.md5sums = create_md5sums(test_env.testing_paths)
      test_env.setup_done = true
      title("RUNNING TESTS")
   end
   
   if extra_rocks then 
      local make_manifest = download_rocks(extra_rocks, test_env.testing_paths.testing_server)
      if make_manifest then
         test_env.run.luarocks_admin_nocov("make_manifest " .. test_env.testing_paths.testing_server)
      end
   end

   if test_env.RESET_ENV then
      reset_environment(test_env.testing_paths, test_env.md5sums, test_env.env_variables)
   end
   
   lfs.chdir(test_env.testing_paths.testrun_dir)
end

--- Test if required rock is installed and if not, install it.
-- Return `true` if the rock is already installed or has been installed successfully,
-- `false` if installation failed.
function test_env.need_rock(rock)
   print("Check if " .. rock .. " is installed")
   if test_env.run.luarocks_noprint_nocov(test_env.quiet("show " .. rock)) then
      return true
   else
      return test_env.run.luarocks_noprint_nocov(test_env.quiet("install " .. rock))
   end
end

--- For each key-value pair in replacements table
-- replace %{key} in given string with value.
local function substitute(str, replacements)
   return (str:gsub("%%%b{}", function(marker)
      return replacements[marker:sub(3, -2)]
   end))
end


--- Create configs for luacov and several versions of Luarocks
-- configs needed for some tests.
local function create_configs()
   -- testing_config.lua and testing_config_show_downloads.lua
   local config_content = substitute([[
      rocks_trees = {
         "%{testing_tree}",
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
      external_deps_dirs = {
         "/usr/local",
         "/usr",
         -- These are used for a test that fails, so it
         -- can point to invalid paths:
         {
            prefix = "/opt",
            bin = "bin",
            include = "include",
            lib = { "lib", "lib64" },
         }
      }
   ]], {
      user = os.getenv("USER"),
      testing_sys_tree = test_env.testing_paths.testing_sys_tree,
      testing_tree = test_env.testing_paths.testing_tree,
      testing_server = test_env.testing_paths.testing_server,
      testing_cache = test_env.testing_paths.testing_cache
   })

   write_file(test_env.testing_paths.testrun_dir .. "/testing_config.lua", config_content .. " \nweb_browser = \"true\"")
   write_file(test_env.testing_paths.testrun_dir .. "/testing_config_show_downloads.lua", config_content
                  .. "show_downloads = true \n rocks_servers={\"http://luarocks.org/repositories/rocks\"}")

   -- testing_config_sftp.lua
   config_content = substitute([[
      rocks_trees = {
         "%{testing_tree}",
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
      user = os.getenv("USER"),
      testing_sys_tree = test_env.testing_paths.testing_sys_tree,
      testing_tree = test_env.testing_paths.testing_tree,
      testing_cache = test_env.testing_paths.testing_cache
   })

   write_file(test_env.testing_paths.testrun_dir .. "/testing_config_sftp.lua", config_content)

   -- luacov.config
   config_content = substitute([[
      return {
         statsfile = "%{testrun_dir}/luacov.stats.out",
         reportfile = "%{testrun_dir}/luacov.report.out",
         modules = {
            ["luarocks"] = "src/bin/luarocks",
            ["luarocks-admin"] = "src/bin/luarocks-admin",
            ["luarocks.*"] = "src",
            ["luarocks.*.*"] = "src",
            ["luarocks.*.*.*"] = "src"
         }
      }
   ]], {
      testrun_dir = test_env.testing_paths.testrun_dir
   })

   write_file(test_env.testing_paths.testrun_dir .. "/luacov.config", config_content)

   config_content = [[
      -- Config file of mock LuaRocks.org site for tests
      upload = {
         server = "http://localhost:8080",
         tool_version = "1.0.0",
         api_version = "1",
      }
   ]]
   write_file(test_env.testing_paths.testrun_dir .. "/luarocks_site.lua", config_content)
end

--- Remove testing directories.
local function clean()
   print("Cleaning testing directory...")
   test_env.remove_dir(test_env.testing_paths.luarocks_tmp)
   test_env.remove_subdirs(test_env.testing_paths.testrun_dir, "testing[_%-]")
   test_env.remove_files(test_env.testing_paths.testrun_dir, "testing_")
   test_env.remove_files(test_env.testing_paths.testrun_dir, "luacov")
   test_env.remove_files(test_env.testing_paths.testrun_dir, "upload_config")
   test_env.remove_files(test_env.testing_paths.testrun_dir, "luarocks_site")
   print("Cleaning done!")
end

--- Install luarocks into testing prefix.
local function install_luarocks(install_env_vars)
   local testing_paths = test_env.testing_paths
   title("Installing LuaRocks")
   if test_env.TEST_TARGET_OS == "windows" then
      local compiler_flag = test_env.MINGW and "/MW" or ""
      assert(execute_bool("install.bat /LUA " .. testing_paths.luadir .. " " .. compiler_flag .. " /P " .. testing_paths.testing_lrprefix .. " /NOREG /NOADMIN /F /Q /CONFIG " .. testing_paths.testing_lrprefix .. "/etc/luarocks", false, install_env_vars))
      assert(execute_bool(testing_paths.win_tools .. "/cp " .. testing_paths.testing_lrprefix .. "/lua/luarocks/core/site_config* " .. testing_paths.src_dir .. "/luarocks/core"))
   else
      local configure_cmd = "./configure --with-lua=" .. testing_paths.luadir .. " --prefix=" .. testing_paths.testing_lrprefix
      assert(execute_bool(configure_cmd, false, install_env_vars))
      assert(execute_bool("make clean", false, install_env_vars))
      assert(execute_bool("make src/luarocks/core/site_config_"..test_env.lua_version:gsub("%.", "_")..".lua", false, install_env_vars))
      assert(execute_bool("make dev", false, install_env_vars))
   end
   print("LuaRocks installed correctly!")
end

function test_env.mock_server_extra_rocks(more)
   local rocks = {
      -- rocks needed for mock-server
      "/copas-2.0.1-1.src.rock",
      "/coxpcall-1.16.0-1.src.rock",
      "/dkjson-2.5-2.src.rock",
      "/luafilesystem-1.6.3-1.src.rock",
      "/luasec-0.6-1.rockspec",
      "/luasocket-3.0rc1-2.src.rock",
      "/luasocket-3.0rc1-2.rockspec",
      "/restserver-0.1-1.src.rock",
      "/restserver-xavante-0.2-1.src.rock",
      "/rings-1.3.0-1.src.rock",
      "/wsapi-1.6.1-1.src.rock",
      "/wsapi-xavante-1.6.1-1.src.rock",
      "/xavante-2.4.0-1.src.rock"
   }
   if more then
      for _, rock in ipairs(more) do
         table.insert(rocks, rock)
      end
   end
   return rocks
end

function test_env.mock_server_init()
   local testing_paths = test_env.testing_paths
   assert(test_env.need_rock("restserver-xavante"))
   local pwd = lfs.currentdir()
   lfs.chdir(testing_paths.fixtures_dir)
   local final_command = test_env.execute_helper(testing_paths.lua .. " " .. testing_paths.util_dir .. "/mock-server.lua &", true, test_env.env_variables)
   os.execute(final_command)
   lfs.chdir(pwd)
end

function test_env.mock_server_done()
   os.execute("curl localhost:8080/shutdown")
end

---
-- Main function to create config files and testing environment 
function test_env.main()
   local testing_paths = test_env.testing_paths

   if test_env.TEST_ENV_CLEAN then
      clean()
   end

   lfs.mkdir(testing_paths.testrun_dir)
   lfs.mkdir(testing_paths.testing_cache)
   lfs.mkdir(testing_paths.luarocks_tmp)

   create_configs()

   local install_env_vars = {
      LUAROCKS_CONFIG = test_env.testing_paths.testrun_dir .. "/testing_config.lua"
   }

   install_luarocks(install_env_vars)

   -- Preparation of rocks for building environment
   local rocks = {} -- names of rocks, required for building environment
   local urls = {}  -- names of rock and rockspec files to be downloaded
   table.insert(urls, "/luacov-0.11.0-1.rockspec")
   table.insert(urls, "/luacov-0.11.0-1.src.rock")

   if test_env.TYPE_TEST_ENV == "full" then
      table.insert(urls, "/luafilesystem-1.6.3-1.src.rock")
      table.insert(urls, "/luasocket-3.0rc1-1.src.rock")
      table.insert(urls, "/luasocket-3.0rc1-1.rockspec")
      table.insert(urls, "/luaposix-33.2.1-1.src.rock")
      table.insert(urls, "/md5-1.2-1.src.rock")
      table.insert(urls, "/lzlib-0.4.1.53-1.src.rock")
      rocks = {"luafilesystem", "luasocket", "luaposix", "md5", "lzlib"}

      if test_env.LUA_V ~= "5.1" then
         table.insert(urls, "/luabitop-1.0.2-1.rockspec")
         table.insert(urls, "/luabitop-1.0.2-1.src.rock")
         table.insert(rocks, "luabitop")
      end
   end

   table.insert(rocks, "luacov")   -- luacov is needed for minimal or full environment

   -- Download rocks needed for LuaRocks testing environment
   lfs.mkdir(testing_paths.testing_server)
   download_rocks(urls, testing_paths.testing_server)
   build_environment(rocks, install_env_vars)
end

test_env.set_lua_version()
test_env.set_args()
test_env.testing_paths = create_paths(test_env.LUA_V or test_env.LUAJIT_V)
test_env.env_variables = create_env(test_env.testing_paths)
test_env.run = make_run_functions()

return test_env
