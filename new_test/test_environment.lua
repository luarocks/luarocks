local lfs = require("lfs")
local test_env = {}

local arg = arg or { ... }

function test_env.set_args()
      if arg[1] == nil then
      print("LuaRocks test-suite\n\n"..
         [[
   INFORMATION
      Lua installed and added to path needed. 

   USAGE
      lua=<version> (mandatory) type your full version of Lua (e.g. --lua 5.2.4)
      env=<type>   (default:"minimal") type what kind of environment to use ["minimal", "full"]
      clean  remove existing testing environment
      os=<version>    type your OS ["linux", "os x", "windows"]
         ]]);
      os.exit()
   end
   test_env.TYPE_TEST_ENV = "minimal"

   for i=1, #arg do
      if arg[i]:find("lua=") then
         test_env.LUA_V = arg[i]:gsub("lua=","")
      end
      if arg[i]:find("env=") then
         test_env.TYPE_TEST_ENV = arg[i]:gsub("env=","")
      end
      if arg[i]:find("clean") then
         test_env.TEST_CLEAN = "yes"
      end
      if arg[i]:find("os=") then
         test_env.TEST_TARGET_OS = arg[i]:gsub("os=","")
      end
   end

   if not test_env.TEST_TARGET_OS then
      print("-=OS check=-")
      if os.execute("sw_vers") then 
         test_env.TEST_TARGET_OS = "os x"
      elseif os.execute("uname -s") then
         test_env.TEST_TARGET_OS = "linux"
      else
         test_env.TEST_TARGET_OS = "windows"
      end
      print("--------------")
   end
end

--- Remove directory recursively
-- @param path string: directory path to delete
local function remove_dir(path)
   if lfs.attributes(path) then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            local full_path = path..'/'..file
            local attr = lfs.attributes(full_path)

            if attr.mode == "directory" then
               remove_dir(full_path)
               os.remove(full_path)
            else
               os.remove(full_path)
            end
         end
      end
   end
end

--- Helper function for execute_bool and execute_output
-- @param command string: command to execute
-- @param print_command boolean: print command if 'true'
-- @param env_variables table: table of environment variables to export {FOO="bar", BAR="foo"}
-- @return final_command string: concatenated command to execution
local function execute_helper(command, print_command, env_variables)
   local final_command = ""
   if print_command then 
      print("Executing: " .. command)
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
   local command = execute_helper(command, print_command, env_variables)
   
   local ok = os.execute(command)
   return ok == true or ok == 0
end

--- Execute command and returns output of command
-- @return output string: output the command execution
local function execute_output(command, print_command, env_variables)
   local command = execute_helper(command, print_command, env_variables)

   local file = assert(io.popen(command))
   local output = file:read('*all')
   file:close()
   return output
end

--- Function for downloading rocks and rockspecs
-- @param rocks table: table with full name of rocks/rockspecs to download
-- @param save_path string: path to directory, where to download rocks/rockspecs
local function download_rocks(rocks, save_path)
   local luarocks_repo = "https://luarocks.org"   
   for _,rock in ipairs(rocks) do  
      -- check if already downloaded
      if not os.rename( save_path .. rock, save_path .. rock) then
         execute_bool("wget -cP " .. save_path .. " " .. luarocks_repo .. rock)  
      end
   end
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
local function hash_environment(path)
   local hash = ""
   if test_env.TEST_TARGET_OS == "linux" then
      hash = execute_output("find . -printf \"%s %p\n\" | md5sum")
   end
   if test_env.TEST_TARGET_OS == "os x" then
      hash = execute_output("find " .. path .. " -type f -exec stat -f \"%z %N\" {} \\; | md5")
   end
   -- if test_env.TEST_TARGET_OS == "windows" then
   --    hash = execute_output("find . -printf \"%s %p\n\" | md5sum")
   -- end
   return hash
end

function test_env.create_env(testing_paths)
   local luaversion_short = _VERSION:gsub("Lua ", "")
   local env_variables = {}

   env_variables.LUAROCKS_CONFIG = testing_paths.testing_dir .. "/testing_config.lua"
   env_variables.LUA_PATH = testing_paths.testing_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_sys_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.testing_sys_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
   env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_paths.src_dir .. "/?.lua;"
   env_variables.LUA_CPATH = testing_paths.testing_tree .. "/lib/lua/5.1/?.so;" .. testing_paths.testing_sys_tree .. "/lib/lua/5.1/?.so;"
   env_variables.PATH = os.getenv("PATH") .. ":" .. testing_paths.testing_tree .. "/bin:" .. testing_paths.testing_sys_tree .. "/bin"

   return env_variables
end

function test_env.create_md5sums(testing_paths)
   local md5sums = {}
   md5sums.testing_tree_copy_md5 = hash_environment(testing_paths.testing_tree_copy)
   md5sums.testing_sys_tree_copy_md5 = hash_environment(testing_paths.testing_sys_tree_copy)

   return md5sums
end

function test_env.run_luarocks(testing_paths, env_variables)
   local run = {}
   local luadir

   if lfs.attributes("/usr/bin/lua") then 
      luadir = "/usr"
   elseif lfs.attributes("/usr/local/bin/lua") then
      luadir = "/usr/local"
   end

   local lua = luadir .. "/bin/lua"

   run.luarocks = function(cmd, env_variables) return execute_output(lua .. " -e\"require('luacov.runner')('" .. testing_paths.testing_dir
               .. "/luacov.config')\" " .. testing_paths.src_dir .. "/bin/luarocks" .. cmd, true, env_variables) end
   run.luarocks_bool = function(cmd, env_variables) return execute_bool(lua .. " -e\"require('luacov.runner')('" .. testing_paths.testing_dir
                     .. "/luacov.config')\" " .. testing_paths.src_dir .. "/bin/luarocks" .. cmd, true, env_variables) end
   run.luarocks_nocov = function(cmd, env_variables) return execute_bool(lua .. " " .. testing_paths.src_dir .. "/bin/luarocks" .. cmd,
                      true, env_variables) end
   run.luarocks_noprint= function(cmd, env_variables) return execute_output(lua .. " -e\"require('luacov.runner')('" .. testing_paths.testing_dir
                              .. "/luacov.config')\" " .. testing_paths.src_dir .. "/bin/luarocks" .. cmd, false, env_variables) end
   run.luarocks_noprint_nocov = function(cmd, env_variables) return execute_bool(lua .. " " .. testing_paths.src_dir .. "/bin/luarocks" .. cmd,
                                          false, env_variables) end
   run.luarocks_admin = function(cmd, env_variables) return execute_bool(lua .. " -e\"require('luacov.runner')('" .. testing_paths.testing_dir
                              .. "/luacov.config')\" " .. testing_paths.src_dir .. "/bin/luarocks-admin" .. cmd, true, env_variables) end
   run.luarocks_admin_nocov = function(cmd, env_variables) return execute_bool(lua .. " " .. testing_paths.src_dir .. "/bin/luarocks-admin" .. cmd,
                                       true, env_variables) end
   return run
end

--- Build environment for testing
local function build_environment(environment, testing_paths, env_variables)
   print("\n--------------------")
   print("Building environment")
   print("--------------------")
   remove_dir(testing_paths.testing_tree)
   remove_dir(testing_paths.testing_sys_tree)
   remove_dir(testing_paths.testing_tree_copy)
   remove_dir(testing_paths.testing_sys_tree_copy)

   execute_bool("mkdir " .. testing_paths.testing_tree)
   execute_bool("mkdir " .. testing_paths.testing_sys_tree)

   local run = test_env.run_luarocks(testing_paths, env_variables)
   run.luarocks_admin_nocov(" make_manifest " .. testing_paths.testing_cache, env_variables)  

   for _,package in ipairs(environment) do
      if not run.luarocks_nocov(" install --only-server=" .. testing_paths.testing_cache .. " --tree=" .. testing_paths.testing_sys_tree .. " " .. package, env_variables) then
         run.luarocks_nocov(" build --tree=" .. testing_paths.testing_sys_tree .. " " .. package, env_variables)
         run.luarocks_nocov(" pack --tree=" .. testing_paths.testing_sys_tree .. " " .. package .. "; mv " .. package .. "-*.rock " .. testing_paths.testing_cache, env_variables)
      end
   end

   -- Creating environment variables
   env_variables = test_env.create_env(testing_paths)

   execute_bool("cp -a " .. testing_paths.testing_tree .. "/." .. " " .. testing_paths.testing_tree_copy)
   execute_bool("cp -a " .. testing_paths.testing_sys_tree .. "/." .. " " .. testing_paths.testing_sys_tree_copy)
end

--- Reset testing environment
function test_env.reset_environment(testing_paths, md5sums)
   testing_tree_md5 = hash_environment(testing_paths.testing_tree)
   testing_sys_tree_md5 = hash_environment(testing_paths.testing_sys_tree)

   if testing_tree_md5 ~= md5sums.testing_tree_copy_md5 then
      remove_dir(testing_paths.testing_tree)
      execute_bool("cp -a " .. testing_paths.testing_tree_copy .. "/." .. " " .. testing_paths.testing_tree)
   end
   if testing_sys_tree_md5 ~= md5sums.testing_sys_tree_copy_md5 then
      remove_dir(testing_paths.testing_sys_tree)
      execute_bool("cp -a " .. testing_paths.testing_sys_tree_copy .. "/." .. " " .. testing_paths.testing_sys_tree)
   end
   print("\n-=Environment reseted=-")
end

function test_env.set_paths(luaversion_full)
   local testing_paths = {}
   testing_paths.luarocks_dir = lfs.currentdir():gsub("/new_test","")
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


---
-- MAIN 
function test_env.main(rocks)
   test_env.set_args()
   local luaversion_full = test_env.LUA_V
   local testing_paths = test_env.set_paths(luaversion_full)
  
   --TODO
   if test_env.TEST_CLEAN == "yes" then
      remove_dir(testing_cache)
      remove_dir(testing_server)
   end

   execute_bool("mkdir " .. testing_paths.testing_cache)

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
   create_config(testing_paths.testing_dir .. "/testing_config_show_downloads.lua", config_content .. "show_downloads = true")

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

   -- Export environment variables
   local temp_env_variables = {LUAROCKS_CONFIG = testing_paths.testing_dir .. "/testing_config.lua",LUA_PATH="",LUA_CPATH=""}

   -- TRAVIS TODO
   -- luadir = "/tmp/lua-" .. luaversion

   --LOCAL
   local luadir

   if lfs.attributes("/usr/bin/lua") then 
      luadir = "/usr"
   elseif lfs.attributes("/usr/local/bin/lua") then
      luadir = "/usr/local"
   end

   lfs.chdir(testing_paths.luarocks_dir)
   execute_bool("./configure --with-lua=" .. luadir .. " --prefix=" .. testing_paths.testing_lrprefix
                        .. " && make clean", false, temp_env_variables)
   execute_bool("make src/luarocks/site_config.lua && make dev", false, temp_env_variables)
   lfs.chdir(testing_paths.src_dir)

   local run = test_env.run_luarocks(testing_paths, temp_env_variables)
   execute_bool("mkdir " .. testing_paths.testing_server)

   download_rocks(rocks, testing_paths.testing_server)
   lfs.chdir(testing_paths.luarocks_dir)

   -- Preparation of environment to build
   run.luarocks_admin_nocov(" make_manifest " .. testing_paths.testing_server, temp_env_variables)
   local minimal_environment = {"luacov"}
   local full_environment = {}

   if luaversion_full == "5.1.5" then
      full_environment = {"luacov", "luafilesystem", "luasocket", "luabitop","luaposix", "md5", "lzlib"}
   else
      full_environment = {"luacov", "luafilesystem", "luasocket", "luaposix", "md5", "lzlib"}
   end

   -- Build environments
   if test_env.TYPE_TEST_ENV == "full" then
      build_environment(full_environment, testing_paths, temp_env_variables)
   else
      build_environment(minimal_environment, testing_paths, temp_env_variables)
   end
   print("--------------")
   print("Running tests")
   print("--------------")
end

return test_env
