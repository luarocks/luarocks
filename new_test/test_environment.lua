local lfs = require("lfs")
local test_env = {}
local arg = arg or { ... }

--- Set all arguments from input into global variables
function test_env.set_args()
      if arg[1] == nil then
      print("LuaRocks test-suite\n\n"..
         [[
   INFORMATION
      Lua installed and added to path needed. 

   USAGE -Xhelper <arguments>
      lua=<version> (mandatory) type your full version of Lua (e.g. --lua 5.2.4)
      env=<type>   (default:"minimal") type what kind of environment to use ["minimal", "full"]
      clean  remove existing testing environment
      os=<version>    type your OS ["linux", "os x", "windows"]
         ]]);
      os.exit(1)
   end
   test_env.TYPE_TEST_ENV = "minimal"

   for i=1, #arg do
      if arg[i]:find("lua=") then
         test_env.LUA_V = arg[i]:gsub("(.*)lua=([^%,]+)(.*)","%2") -- !needed coz from busted file I receive params in string...!
      end
      if arg[i]:find("env=") then
         test_env.TYPE_TEST_ENV = arg[i]:gsub("(.*)env=([^%,]+)(.*)","%2")
      end
      if arg[i]:find("clean") then
         test_env.TEST_ENV_CLEAN = true
      end
      if arg[i]:find("travis") then
         test_env.TRAVIS = true
      end
      if arg[i]:find("os=") then
         test_env.TEST_TARGET_OS = arg[i]:gsub("(.*)os=([^%,]+)(.*)","%2")
      end
   end

   if not test_env.TEST_TARGET_OS then
      print("[OS CHECK]")
      if os.execute("sw_vers") then 
         test_env.TEST_TARGET_OS = "osx"
      elseif os.execute("uname -s") then
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
            local attr = lfs.attributes(full_path)

            if attr.mode == "directory" then
               test_env.remove_dir(full_path)
               os.remove(full_path)
            else
               os.remove(full_path)
            end
         end
      end
   end
   os.remove(path)
end

--- Remove files based on filename
-- @param path string: directory where to delete files
-- @param pattern string: pattern in filenames
function test_env.remove_files(path, pattern)
   local result_check = false
   if lfs.attributes(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            if file:find(pattern) then
               if os.remove(file) then
                  result_check = true
               end
            end
         end
      end
   end
   return result_check
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

--- Function for downloading rocks and rockspecs
-- @param rocks table: table with full name of rocks/rockspecs to download
-- @param save_path string: path to directory, where to download rocks/rockspecs
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

--- Create config files for testing
-- @param config_path string: path where to save config file
-- @param config_content string: content of this config file
local function create_config(config_path, config_content)
   local file, err = io.open(config_path, "w+")
   if not file then return nil, err end
   file:write(config_content)
   file:close()
end

--- Create md5checksum of directory structure recursively
-- based on filename and size
-- @param path string: path to directory for generate mg5checksum
-- @param testing_os string(optional): version of PC OS
local function hash_environment(path, testing_os)
   local hash = ""
   testing_os = testing_os or test_env.TEST_TARGET_OS

   if testing_os == "linux" then
      hash = execute_output("find . -printf \"%s %p\n\" | md5sum")
   end
   if testing_os == "osx" then
      hash = execute_output("find " .. path .. " -type f -exec stat -f \"%z %N\" {} \\; | md5")
   end
   -- if testing_os == "windows" then
   --    hash = execute_output("find . -printf \"%s %p\n\" | md5sum")
   -- end
   return hash
end

local function create_env(testing_paths)
   local luaversion_short = _VERSION:gsub("Lua ", "")
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

local function create_md5sums(testing_paths)
   local md5sums = {}
   md5sums.testing_tree_copy_md5 = hash_environment(testing_paths.testing_tree_copy)
   md5sums.testing_sys_tree_copy_md5 = hash_environment(testing_paths.testing_sys_tree_copy)

   return md5sums
end

local function run_luarocks(testing_paths, env_variables)
   
   local function make_command_function(exec_function, lua_cmd, do_print)
      return function(cmd, new_vars)
         local temp_vars = {}
         for k, v in pairs(env_variables) do
            temp_vars[k] = v
         end
         if new_vars then
            for k, v in pairs(new_vars) do
               temp_vars[k] = v
            end
         end
         return exec_function(lua_cmd .. cmd, do_print, temp_vars)
      end
   end

   local run = {}

   local cov_str = testing_paths.lua .. " -e\"require('luacov.runner')('" .. testing_paths.testing_dir .. "/luacov.config')\" " .. testing_paths.src_dir

   local luarocks_cmd = cov_str .. "/bin/luarocks "
   run.luarocks = make_command_function(execute_output, luarocks_cmd, true)
   run.luarocks_bool = make_command_function(execute_bool, luarocks_cmd, true)
   run.luarocks_noprint = make_command_function(execute_bool, luarocks_cmd, false)

   local luarocks_nocov_cmd = testing_paths.lua .. " " .. testing_paths.src_dir .. "/bin/luarocks "
   run.luarocks_nocov = make_command_function(execute_bool, luarocks_nocov_cmd, true)
   run.luarocks_noprint_nocov = make_command_function(execute_bool, luarocks_nocov_cmd, false)
   

   local luarocks_admin_cmd = cov_str .. "/bin/luarocks-admin "
   run.luarocks_admin = make_command_function(execute_output, luarocks_admin_cmd, true)
   run.luarocks_admin_bool = make_command_function(execute_bool, luarocks_admin_cmd, true)

   local luarocks_admin_nocov_cmd = testing_paths.lua .. " " .. testing_paths.src_dir .. "/bin/luarocks-admin "
   run.luarocks_admin_nocov = make_command_function(execute_bool, luarocks_admin_nocov_cmd, false)

   return run
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

   execute_bool("mkdir " .. testing_paths.testing_tree)
   execute_bool("mkdir " .. testing_paths.testing_sys_tree)

   local run = run_luarocks(testing_paths, env_variables)
   run.luarocks_admin_nocov("make_manifest " .. testing_paths.testing_server)
   run.luarocks_admin_nocov("make_manifest " .. testing_paths.testing_cache)

   for _,package in ipairs(env_rocks) do
      if not run.luarocks_nocov("install --only-server=" .. testing_paths.testing_cache .. " --tree=" .. testing_paths.testing_sys_tree .. " " .. package, env_variables) then
         run.luarocks_nocov("build --tree=" .. testing_paths.testing_sys_tree .. " " .. package, env_variables)
         run.luarocks_nocov("pack --tree=" .. testing_paths.testing_sys_tree .. " " .. package .. "; mv " .. package .. "-*.rock " .. testing_paths.testing_cache, env_variables)
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

local function set_paths(luaversion_full)
   local testing_paths = {}

   testing_paths.luadir = ""

   if test_env.TRAVIS then
      testing_paths.luadir = lfs.currentdir() .. "/lua_install"
   else
      if lfs.attributes("/usr/bin/lua") then 
         testing_paths.luadir = lfs.currentdir() .. "/usr"
      elseif lfs.attributes("/usr/local/bin/lua") then
         testing_paths.luadir = "/usr/local"
      end
   end

   testing_paths.lua = testing_paths.luadir .. "/bin/lua"
   
   testing_paths.luarocks_dir = lfs.currentdir()
   testing_paths.testing_dir = testing_paths.luarocks_dir .. "/new_test"
   testing_paths.src_dir = testing_paths.luarocks_dir .. "/src"
   testing_paths.luarocks_temp = testing_paths.testing_dir .. "/luarocks-2.3.0"

   testing_paths.testing_lrprefix = testing_paths.testing_dir .. "/testing_lrprefix-" .. luaversion_full
   testing_paths.testing_tree = testing_paths.testing_dir .. "/testing-" .. luaversion_full
   testing_paths.testing_sys_tree = testing_paths.testing_dir .. "/testing_sys-" .. luaversion_full
   testing_paths.testing_tree_copy = testing_paths.testing_dir .. "/testing_copy-" .. luaversion_full
   testing_paths.testing_sys_tree_copy = testing_paths.testing_dir .. "/testing_sys_copy-" .. luaversion_full
   testing_paths.testing_cache = testing_paths.testing_dir .. "/testing_cache-" .. luaversion_full
   testing_paths.testing_server = testing_paths.testing_dir .. "/testing_server-" .. luaversion_full

   return testing_paths
end


test_env.setup_done = false
function test_env.setup_specs(extra_rocks, luaversion_full)
   if not test_env.setup_done then
      test_env.set_args()

      luaversion_full = luaversion_full or test_env.LUA_V

      test_env.main()

      -- Set paths, env_vars and functions for specs
      test_env.testing_paths = set_paths(luaversion_full)
      test_env.env_variables = create_env(test_env.testing_paths)
      test_env.run = run_luarocks(test_env.testing_paths, test_env.env_variables)
      test_env.platform = execute_output(test_env.testing_paths.lua .. " -e 'print(require(\"luarocks.cfg\").arch)'", false, test_env.env_variables)
      test_env.md5sums = create_md5sums(test_env.testing_paths)
      test_env.setup_done = true
   end
   
   if extra_rocks then 
      local make_manifest = download_rocks(extra_rocks, test_env.testing_paths.testing_server)
      if make_manifest then
         local run = run_luarocks(test_env.testing_paths, test_env.env_variables)
         run.luarocks_admin_nocov("make_manifest " .. test_env.testing_paths.testing_server)
      end
   end

   reset_environment(test_env.testing_paths, test_env.md5sums, test_env.env_variables)

   return true
end

--- Helper function for tests which needs luasocket installed
function test_env.need_luasocket(luarocks_nocov, testing_cache, platform)
   luarocks_nocov = luarocks_nocov or test_env.run.luarocks_nocov
   testing_cache = testing_cache or test_env.testing_paths.testing_cache
   platform = platform or test_env.platform

   if luarocks_nocov("show luasocket") then
      return true
   else
      testing_cache = testing_cache .. "/"
      local luasocket_rock = "luasocket-3.0rc1-1." .. platform .. ".rock"
      if not os.rename( testing_cache .. luasocket_rock, testing_cache .. luasocket_rock) then
         luarocks_nocov("build --pack-binary-rock luasocket 3.0rc1-1")
         os.rename(luasocket_rock, testing_cache .. luasocket_rock)
      end
      luarocks_nocov("install " .. testing_cache .. luasocket_rock)
   end
   return true
end

---
-- MAIN 
function test_env.main(luaversion_full, env_type, env_clean)
   luaversion_full = luaversion_full or test_env.LUA_V
   local testing_paths = set_paths(luaversion_full)

   env_clean = env_clean or test_env.TEST_ENV_CLEAN
   if env_clean then
      test_env.remove_dir(testing_paths.testing_cache)
      test_env.remove_dir(testing_paths.testing_server)
   end

   execute_bool("mkdir " .. testing_paths.testing_cache)
   execute_bool("mkdir /tmp/luarocks_testing")
--- CONFIG FILES
-- testing_config.lua and testing_config_show_downloads.lua
   local config_content = ([[rocks_trees = {
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
}]]):gsub("%%%b{}", {
    ["%{user}"] = os.getenv("USER"),
    ["%{testing_sys_tree}"] = testing_paths.testing_sys_tree,
    ["%{testing_tree}"] = testing_paths.testing_tree,
    ["%{testing_server}"] = testing_paths.testing_server,
    ["%{testing_cache}"] = testing_paths.testing_cache})

   create_config(testing_paths.testing_dir .. "/testing_config.lua", config_content)
   create_config(testing_paths.testing_dir .. "/testing_config_show_downloads.lua", config_content
                  .. "show_downloads = true \n rocks_servers={\"http://luarocks.org/repositories/rocks\"}")

-- testing_config_sftp.lua
   config_content=([[rocks_trees = {
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
}]]):gsub("%%%b{}", {
    ["%{user}"] = os.getenv("USER"),
    ["%{testing_sys_tree}"] = testing_paths.testing_sys_tree,
    ["%{testing_tree}"] = testing_paths.testing_tree,
    ["%{testing_cache}"] = testing_paths.testing_cache})

   create_config(testing_paths.testing_dir .. "/testing_config_sftp.lua", config_content)

-- luacov.config
   config_content=([[return {
   statsfile = "%{testing_dir}/luacov.stats.out",
   reportfile = "%{testing_dir}/luacov.report.out",
   modules = {
      ["luarocks"] = "src/bin/luarocks",
      ["luarocks-admin"] = "src/bin/luarocks-admin",
      ["luarocks.*"] = "src",
      ["luarocks.*.*"] = "src",
      ["luarocks.*.*.*"] = "src"
   }
}]]):gsub("%%%b{}", {
    ["%{testing_dir}"] = testing_paths.testing_dir})

   create_config(testing_paths.testing_dir .. "/luacov.config", config_content)

   -- Create environment variables for configuration
   local temp_env_variables = {LUAROCKS_CONFIG = testing_paths.testing_dir .. "/testing_config.lua",LUA_PATH="",LUA_CPATH=""}

   -- Configure LuaRocks testing environment
   lfs.chdir(testing_paths.luarocks_dir)
   local configure_cmd = "./configure --with-lua=" .. testing_paths.luadir .. " --prefix=" .. testing_paths.testing_lrprefix .. " && make clean"
   if not execute_bool(configure_cmd, false, temp_env_variables) then
      os.exit(1)
   end
   if not execute_bool("make src/luarocks/site_config.lua && make dev", false, temp_env_variables) then 
      os.exit(1)
   end

   -- Preparation of rocks for building environment
   env_type = env_type or test_env.TYPE_TEST_ENV
   
   local env_rocks = {} -- short names of rocks, required for building environment
   local rocks = {}  -- full names of rocks required for download
   rocks[#rocks+1] = "/luacov-0.11.0-1.rockspec"
   rocks[#rocks+1] = "/luacov-0.11.0-1.src.rock"

   if env_type == "full" then 
      rocks[#rocks+1] = "/luafilesystem-1.6.3-1.src.rock"
      rocks[#rocks+1] = "/luasocket-3.0rc1-1.src.rock"
      rocks[#rocks+1] = "/luasocket-3.0rc1-1.rockspec"
      rocks[#rocks+1] = "/luaposix-33.2.1-1.src.rock"
      rocks[#rocks+1] = "/md5-1.2-1.src.rock"
      rocks[#rocks+1] = "/lzlib-0.4.1.53-1.src.rock"
      env_rocks = {"luafilesystem", "luasocket", "luaposix", "md5", "lzlib"}
   end
   if env_type == "full" and luaversion_full ~= "5.1.5" then
      rocks[#rocks+1] = "/luabitop-1.0.2-1.rockspec"
      rocks[#rocks+1] = "/luabitop-1.0.2-1.src.rock"
      table.insert(env_rocks, "luabitop")
   end

   table.insert(env_rocks, "luacov")   -- luacov is needed for minimal or full environments
   
   -- Download rocks needed for LuaRocks testing environment
   execute_bool("mkdir " .. testing_paths.testing_server)
   download_rocks(rocks, testing_paths.testing_server)
   
   build_environment(env_rocks, testing_paths, temp_env_variables)

   print("----------------")
   print(" RUNNING  TESTS")
   print("----------------")
end

return test_env
