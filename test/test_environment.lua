local lfs = require("lfs")
local test_env = {}

local help_message = [[
LuaRocks test-suite

INFORMATION
   New test-suite for LuaRocks project, using unit testing framework Busted.
REQUIREMENTS
   Tests require to have Lua installed and added to PATH. Be sure sshd is
   running on your system, or use '--exclude-tags=ssh', to not execute tests
   which require sshd.
USAGE
   busted [-Xhelper <arguments>]
ARGUMENTS
   env=<type>     Set type of environment to use ("minimal" or "full",
                  default: "minimal").
   clean          Remove existing testing environment.
   travis         Add if running on TravisCI.
   os=<type>      Set OS ("linux", "osx", or "windows").
]]

local function help()
   print(help_message)
   os.exit(1)
end

--- Helper function for execute_bool and execute_output
-- @param command string: command to execute
-- @param print_command boolean: print command if 'true'
-- @param env_variables table: table of environment variables to export {FOO="bar", BAR="foo"}
-- @return final_command string: concatenated command to execution
local function execute_helper(command, print_command, env_variables)
   local final_command = ""

   if print_command then 
      print("\n[EXECUTING]: " .. command)
   end

   if env_variables then
      final_command = "export "
      for k,v in pairs(env_variables) do
         final_command = final_command .. k .. "='" .. v .. "' "
      end
      -- remove last space and add ';' to separate exporting variables from command
      final_command = final_command:sub(1, -2) .. "; "
   end

   final_command = final_command .. command

   return final_command
end

--- Execute command and returns true/false
-- In Lua5.1 os.execute returns numeric value, but in Lua5.2+ returns boolean
-- @return true/false boolean: status of the command execution
local function execute_bool(command, print_command, env_variables)
   command = execute_helper(command, print_command, env_variables)
   
   local ok = os.execute(command)
   return ok == true or ok == 0
end

--- Execute command and returns output of command
-- @return output string: output the command execution
local function execute_output(command, print_command, env_variables)
   command = execute_helper(command, print_command, env_variables)

   local file = assert(io.popen(command))
   local output = file:read('*all')
   file:close()
   return output:gsub("\n","") -- output adding new line, need to be removed
end

--- Set test_env.LUA_V or test_env.LUAJIT_V based
-- on version of Lua used to run this script.
function test_env.set_lua_version()
   if _G.jit then
      test_env.LUAJIT_V = _G.jit.version:match("(2%.%d)%.%d")
   else
      test_env.LUA_V = _VERSION:match("5%.%d")
   end
end

--- Set all arguments from input into global variables
function test_env.set_args()
   -- if at least Lua/LuaJIT version argument was found on input start to parse other arguments to env. variables
   test_env.TYPE_TEST_ENV = "minimal"

   for _, argument in ipairs(arg) do
      if argument:find("^env=") then
         test_env.TYPE_TEST_ENV = argument:match("^env=(.*)$")
      elseif argument == "clean" then
         test_env.TEST_ENV_CLEAN = true
      elseif argument == "travis" then
         test_env.TRAVIS = true
      elseif argument:find("^os=") then
         test_env.TEST_TARGET_OS = argument:match("^os=(.*)$")
      else
         help()
      end
   end

   if not test_env.TEST_TARGET_OS then
      print("[OS CHECK]")
      if execute_bool("sw_vers") then 
         test_env.TEST_TARGET_OS = "osx"
      elseif execute_bool("uname -s") then
         test_env.TEST_TARGET_OS = "linux"
      else
         test_env.TEST_TARGET_OS = "windows"
      end
      print("--------------")
   end
   return true
end

--- Remove directory recursively
-- @param path string: directory path to delete
function test_env.remove_dir(path)
   if lfs.attributes(path) then
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
   os.remove(path)
end

--- Remove subdirectories of a directory that match a pattern
-- @param path string: path to directory
-- @param pattern string: pattern matching basenames of subdirectories to be removed
function test_env.remove_subdirs(path, pattern)
   if lfs.attributes(path) then
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
   if lfs.attributes(path) then
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
-- @param rocks table: table with full name of rocks/rockspecs to download
-- @param save_path string: path to directory, where to download rocks/rockspecs
-- @return make_manifest boolean: true if new rocks downloaded
local function download_rocks(rocks, save_path)
   local luarocks_repo = "https://luarocks.org"   
   local make_manifest = false

   for _,rock in ipairs(rocks) do  
      -- check if already downloaded
      if not os.rename( save_path .. rock, save_path .. rock) then
         execute_bool("wget -cP " .. save_path .. " " .. luarocks_repo .. rock)
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
      return execute_output("find " .. path .. " -printf \"%s %p\n\" | md5sum")
   elseif test_env.TEST_TARGET_OS == "osx" then
      return execute_output("find " .. path .. " -type f -exec stat -f \"%z %N\" {} \\; | md5")
   else
      -- TODO: Windows
      return ""
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
   env_variables.LUAROCKS_CONFIG = testing_paths.testing_dir .. "/testing_config.lua"
   env_variables.LUA_PATH = testing_paths.testing_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_sys_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_sys_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.src_dir .. "/?.lua;"
   env_variables.LUA_CPATH = testing_paths.testing_tree .. "/lib/lua/" .. luaversion_short .. "/?.so;"
                           .. testing_paths.testing_sys_tree .. "/lib/lua/" .. luaversion_short .. "/?.so;"
   env_variables.PATH = os.getenv("PATH") .. ":" .. testing_paths.testing_tree .. "/bin:" .. testing_paths.testing_sys_tree .. "/bin"

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
   local cmd_prefix = test_env.testing_paths.lua .. " "

   if with_coverage then
      cmd_prefix = cmd_prefix .. "-e \"require('luacov.runner')('" .. test_env.testing_paths.testing_dir .. "/luacov.config')\" "
   end

   cmd_prefix = cmd_prefix .. test_env.testing_paths.src_dir .. "/bin/" .. cmd_name .. " "

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

--- Build environment for testing
local function build_environment(env_rocks, testing_paths, env_variables)
   print("\n--------------------")
   print("BUILDING ENVIRONMENT")
   print("--------------------")
   test_env.remove_dir(testing_paths.testing_tree)
   test_env.remove_dir(testing_paths.testing_sys_tree)
   test_env.remove_dir(testing_paths.testing_tree_copy)
   test_env.remove_dir(testing_paths.testing_sys_tree_copy)

   lfs.mkdir(testing_paths.testing_tree)
   lfs.mkdir(testing_paths.testing_sys_tree)

   test_env.run.luarocks_admin_nocov("make_manifest " .. testing_paths.testing_server)
   test_env.run.luarocks_admin_nocov("make_manifest " .. testing_paths.testing_cache)

   for _,package in ipairs(env_rocks) do
      if not test_env.run.luarocks_nocov("install --only-server=" .. testing_paths.testing_cache .. " --tree=" .. testing_paths.testing_sys_tree .. " " .. package, env_variables) then
         test_env.run.luarocks_nocov("build --tree=" .. testing_paths.testing_sys_tree .. " " .. package, env_variables)
         test_env.run.luarocks_nocov("pack --tree=" .. testing_paths.testing_sys_tree .. " " .. package .. "; mv " .. package .. "-*.rock " .. testing_paths.testing_cache, env_variables)
      end
   end

   execute_bool("cp -a " .. testing_paths.testing_tree .. "/. " .. testing_paths.testing_tree_copy)
   execute_bool("cp -a " .. testing_paths.testing_sys_tree .. "/. " .. testing_paths.testing_sys_tree_copy)
end

--- Reset testing environment
local function reset_environment(testing_paths, md5sums)
   local testing_tree_md5 = hash_environment(testing_paths.testing_tree)
   local testing_sys_tree_md5 = hash_environment(testing_paths.testing_sys_tree)

   if testing_tree_md5 ~= md5sums.testing_tree_copy_md5 then
      test_env.remove_dir(testing_paths.testing_tree)
      execute_bool("cp -a " .. testing_paths.testing_tree_copy .. "/. " .. testing_paths.testing_tree)
   end
   if testing_sys_tree_md5 ~= md5sums.testing_sys_tree_copy_md5 then
      test_env.remove_dir(testing_paths.testing_sys_tree)
      execute_bool("cp -a " .. testing_paths.testing_sys_tree_copy .. "/. " .. testing_paths.testing_sys_tree)
   end

   print("\n[ENVIRONMENT RESET]")
end

local function create_paths(luaversion_full)
   local testing_paths = {}

   testing_paths.luadir = ""

   if test_env.TRAVIS then
      testing_paths.luadir = lfs.currentdir() .. "/lua_install"
      testing_paths.lua = testing_paths.luadir .. "/bin/lua"
   end

   if test_env.LUA_V and not test_env.TRAVIS then
      if lfs.attributes("/usr/bin/lua") then
         testing_paths.luadir = "/usr"
         testing_paths.lua = testing_paths.luadir .. "/bin/lua"
      elseif lfs.attributes("/usr/local/bin/lua") then
         testing_paths.luadir = "/usr/local"
         testing_paths.lua = testing_paths.luadir .. "/bin/lua"
      end
   elseif test_env.LUAJIT_V and not test_env.TRAVIS then
      if lfs.attributes("/usr/bin/luajit") then
         testing_paths.luadir = "/usr"
         testing_paths.lua = testing_paths.luadir .. "/bin/luajit"
      elseif lfs.attributes("/usr/local/bin/luajit") then
         testing_paths.luadir = "/usr/local"
         testing_paths.lua = testing_paths.luadir .. "/bin/luajit"
      end
   end

   testing_paths.luarocks_tmp = "/tmp/luarocks_testing" --windows?

   testing_paths.luarocks_dir = lfs.currentdir()
   testing_paths.testing_dir = testing_paths.luarocks_dir .. "/test"
   testing_paths.src_dir = testing_paths.luarocks_dir .. "/src"
   testing_paths.testing_lrprefix = testing_paths.testing_dir .. "/testing_lrprefix-" .. luaversion_full
   testing_paths.testing_tree = testing_paths.testing_dir .. "/testing-" .. luaversion_full
   testing_paths.testing_tree_copy = testing_paths.testing_dir .. "/testing_copy-" .. luaversion_full
   testing_paths.testing_sys_tree = testing_paths.testing_dir .. "/testing_sys-" .. luaversion_full
   testing_paths.testing_sys_tree_copy = testing_paths.testing_dir .. "/testing_sys_copy-" .. luaversion_full
   testing_paths.testing_cache = testing_paths.testing_dir .. "/testing_cache-" .. luaversion_full
   testing_paths.testing_server = testing_paths.testing_dir .. "/testing_server-" .. luaversion_full

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
end

--- Function for initially setup of environment, variables, md5sums for spec files
function test_env.setup_specs(extra_rocks)
   -- if global variable about successful creation of testing environment doesn't exists, build environment
   if not test_env.setup_done then
      if test_env.TRAVIS then
         if not os.rename(os.getenv("HOME") .. "/.ssh/id_rsa.pub", os.getenv("HOME") .. "/.ssh/id_rsa.pub") then
            execute_bool("ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa")
            execute_bool("cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys")
            execute_bool("chmod og-wx ~/.ssh/authorized_keys")
            execute_bool("ssh-keyscan localhost >> ~/.ssh/known_hosts")
         end
      end

      test_env.main()
      package.path = test_env.env_variables.LUA_PATH

      test_env.platform = execute_output(test_env.testing_paths.lua .. " -e 'print(require(\"luarocks.cfg\").arch)'", false, test_env.env_variables)
      test_env.md5sums = create_md5sums(test_env.testing_paths)
      test_env.setup_done = true
   end
   
   if extra_rocks then 
      local make_manifest = download_rocks(extra_rocks, test_env.testing_paths.testing_server)
      if make_manifest then
         test_env.run.luarocks_admin_nocov("make_manifest " .. test_env.testing_paths.testing_server)
      end
   end

   reset_environment(test_env.testing_paths, test_env.md5sums, test_env.env_variables)

   return true
end

--- Helper function for tests which needs luasocket installed
function test_env.need_luasocket()
   if test_env.run.luarocks_nocov("show luasocket") then
      return true
   else
      local testing_cache = test_env.testing_paths.testing_cache .. "/"
      local luasocket_rock = "luasocket-3.0rc1-1." .. test_env.platform .. ".rock"
      if not os.rename( testing_cache .. luasocket_rock, testing_cache .. luasocket_rock) then
         test_env.run.luarocks_nocov("build --pack-binary-rock luasocket 3.0rc1-1")
         os.rename(luasocket_rock, testing_cache .. luasocket_rock)
      end
      return test_env.run.luarocks_nocov("install " .. testing_cache .. luasocket_rock)
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

   write_file(test_env.testing_paths.testing_dir .. "/testing_config.lua", config_content .. " \nweb_browser = \"true\"")
   write_file(test_env.testing_paths.testing_dir .. "/testing_config_show_downloads.lua", config_content
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

   write_file(test_env.testing_paths.testing_dir .. "/testing_config_sftp.lua", config_content)

   -- luacov.config
   config_content = substitute([[
      return {
         statsfile = "%{testing_dir}/luacov.stats.out",
         reportfile = "%{testing_dir}/luacov.report.out",
         modules = {
            ["luarocks"] = "src/bin/luarocks",
            ["luarocks-admin"] = "src/bin/luarocks-admin",
            ["luarocks.*"] = "src",
            ["luarocks.*.*"] = "src",
            ["luarocks.*.*.*"] = "src"
         }
      }
   ]], {
      testing_dir = test_env.testing_paths.testing_dir
   })

   write_file(test_env.testing_paths.testing_dir .. "/luacov.config", config_content)
end

--- Remove testing directories.
local function clean()
   print("Cleaning testing directory...")
   test_env.remove_dir(test_env.testing_paths.luarocks_tmp)
   test_env.remove_subdirs(test_env.testing_paths.testing_dir, "testing[_%-]")
   test_env.remove_files(test_env.testing_paths.testing_dir, "testing_")
   test_env.remove_files(test_env.testing_paths.testing_dir, "luacov")
   print("Cleaning done!")
end

---
-- Main function to create config files and testing environment 
function test_env.main()
   local testing_paths = test_env.testing_paths

   if test_env.TEST_ENV_CLEAN then
      clean()
   end

   lfs.mkdir(testing_paths.testing_cache)
   lfs.mkdir(testing_paths.luarocks_tmp)

   create_configs()

   -- Create environment variables for configuration
   local temp_env_variables = {LUAROCKS_CONFIG = testing_paths.testing_dir .. "/testing_config.lua",LUA_PATH="",LUA_CPATH=""}

   -- Configure LuaRocks testing environment
   local configure_cmd = "./configure --with-lua=" .. testing_paths.luadir .. " --prefix=" .. testing_paths.testing_lrprefix 
   configure_cmd = configure_cmd .. " && make clean"
   
   if not execute_bool(configure_cmd, false, temp_env_variables) then
      os.exit(1)
   end
   if not execute_bool("make src/luarocks/site_config.lua && make dev", false, temp_env_variables) then 
      os.exit(1)
   end

   -- Preparation of rocks for building environment
   local env_rocks = {} -- short names of rocks, required for building environment
   local rocks = {}  -- full names of rocks required for download
   rocks[#rocks+1] = "/luacov-0.11.0-1.rockspec"
   rocks[#rocks+1] = "/luacov-0.11.0-1.src.rock"

   if test_env.TYPE_TEST_ENV == "full" then 
      rocks[#rocks+1] = "/luafilesystem-1.6.3-1.src.rock"
      rocks[#rocks+1] = "/luasocket-3.0rc1-1.src.rock"
      rocks[#rocks+1] = "/luasocket-3.0rc1-1.rockspec"
      rocks[#rocks+1] = "/luaposix-33.2.1-1.src.rock"
      rocks[#rocks+1] = "/md5-1.2-1.src.rock"
      rocks[#rocks+1] = "/lzlib-0.4.1.53-1.src.rock"
      env_rocks = {"luafilesystem", "luasocket", "luaposix", "md5", "lzlib"}

      if test_env.LUA_V ~= "5.1" then
         rocks[#rocks+1] = "/luabitop-1.0.2-1.rockspec"
         rocks[#rocks+1] = "/luabitop-1.0.2-1.src.rock"
         table.insert(env_rocks, "luabitop")
      end
   end

   table.insert(env_rocks, "luacov")   -- luacov is needed for minimal or full environment
   
   -- Download rocks needed for LuaRocks testing environment
   lfs.mkdir(testing_paths.testing_server)
   download_rocks(rocks, testing_paths.testing_server)
   
   build_environment(env_rocks, testing_paths, temp_env_variables)

   print("----------------")
   print(" RUNNING  TESTS")
   print("----------------")
end

test_env.set_lua_version()
test_env.set_args()
test_env.testing_paths = create_paths(test_env.LUA_V or test_env.LUAJIT_V)
test_env.env_variables = create_env(test_env.testing_paths)
test_env.run = make_run_functions()

return test_env
