local lfs
local test_enviroment = {}

--- Helper function for os.execute() returns numeric in Lua5.1 and boolean in Lua5.2+
-- @param command - string, command to execute
-- @param print_command - boolean, print command if 'true'
-- @param env_variables - table, table of environment variables to export {FOO="bar", BAR="foo"}
-- @return true/false - boolean, status of the command execution
local function execute(command, print_command, env_variables)
	local final_command = ""
	local output = ""

	if env_variables then
		final_command = "export "
		for k,v in pairs(env_variables) do
			final_command = final_command .. k .. "='" .. v .. "' "
		end
		-- remove last space and add ';' to separate exporting variables from command
		final_command = final_command:sub(1, -2) .. "; "
	end
	
	final_command = final_command .. command
	if print_command then 
		print("Executing: " .. final_command)
	end

	final_command = final_command .. " > tmp_command_output"

	local ok = os.execute(final_command)
	
	local file, err = io.open("tmp_command_output", "r")
	if not file then return nil, err end
	output = file:read()
	file:close()
	os.execute("rm tmp_command_output")
	
	return ok == true or ok == 0, output
end

--- Function for downloading rocks and rockspecs
local function get_rocks(rock)
	local luarocks_repo = "https://luarocks.org"
	if not lfs.attributes(rock) then 
		execute("wget -c " .. luarocks_repo .. rock)	
	end
end

--- Create config files
local function create_config(config_path, config_content)
	local file, err = io.open(config_path, "w+")
	if not file then return nil, err end
	file:write(config_content)
	file:close()
end

--- Install required dependencies with LuaRocks stable
local function install_dependencies()
	print("Checking if LuaRocks is installed")
	if execute("luarocks --version") then 
		print("LuaRocks detected\n")
	else
		print("LuaRocks not detected, installing...")
		execute("wget -cP ./new_test http://luarocks.org/releases/luarocks-2.3.0.tar.gz")
		execute("tar zxpf ./new_test/luarocks-2.3.0.tar.gz -C ./new_test/")
		execute("rm ./new_test/luarocks-2.3.0.tar.gz")
		execute("./new_test/luarocks-2.3.0/configure; sudo make bootstrap ./new_test/luarocks-2.3.0/")
		execute("rm -rf ./new_test/luarocks-2.3.0/")
	end

	print("Checking if Busted is installed")
	if execute("busted --version") then 
		print("Busted detected\n")
	else
		print("Busted not detected, installing...")
		execute("luarocks install busted")
	end
	-- after successful installing dependencies, set lfs library
	lfs = require("lfs")
end 

local function hash_environment(path)
	-- if linux
		-- execute("find . -printf "%s %p\n" | md5sum")
	-- if mac
	local _, hash = execute("find " .. path .. " -type f -exec stat -f \"%z %N\" {} \\; | md5")

	return hash
end

--- Build environment for testing
local function build_environment(environment, env_variables)
	print("--------------------")
	print("Building environment")
	execute("rm -rf " .. testing_tree)
	execute("rm -rf " .. testing_sys_tree)
	execute("rm -rf " .. testing_tree_copy)
	execute("rm -rf " .. testing_sys_tree_copy)

	execute("mkdir " .. testing_tree)
	execute("mkdir " .. testing_sys_tree)

	luarocks_admin_nocov(" make_manifest " .. testing_cache, env_variables)  
			
	for _,package in ipairs(environment) do
		if not luarocks_nocov(" install --only-server=" .. testing_cache .. " --tree=" .. testing_sys_tree .. " " .. package, env_variables) then
			luarocks_nocov(" build --tree=" .. testing_sys_tree .. " " .. package, env_variables)
			luarocks_nocov(" pack --tree=" .. testing_sys_tree .. " " .. package .. "; mv " .. package .. "-*.rock " .. testing_cache, env_variables)
		end
	end

	-- Creating environment variables
	env_variables.LUA_PATH = testing_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
	env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
	env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_sys_tree .. "/share/lua/" .. luaversion_short .. "/?.lua;"
	env_variables.LUA_PATH = env_variables.LUA_PATH .. testing_sys_tree .. "/share/lua/".. luaversion_short .. "/?/init.lua;"
	env_variables.LUA_PATH = env_variables.LUA_PATH .. src_dir .. "/?.lua;"
	
	env_variables.LUA_CPATH = testing_tree .. "/lib/lua/5.1/?.so;" .. testing_sys_tree .. "/lib/lua/5.1/?.so;"
	env_variables.PATH = os.getenv("PATH") .. ":" .. testing_tree .. "/bin:" .. testing_sys_tree .. "/bin"

	execute("cp -a " .. testing_tree .. " " .. testing_tree_copy)
	execute("cp -a " .. testing_sys_tree .. " " .. testing_sys_tree_copy)

	local testing_tree_copy_md5 = hash_environment(testing_tree_copy)
	local testing_sys_tree_copy_md5 = hash_environment(testing_sys_tree_copy)
end

---
-- MAIN 
function test_enviroment.run(...)
	local luarocks_found, luarocks_v = execute("luarocks --version")
	local busted_found, busted_v = execute("busted --version")
	if luarocks_found and busted_found then
		print("LuaRocks version: " .. luarocks_v)
		print("Busted version: " .. busted_v)
		lfs = require("lfs")
		print("Dependencies set")
	else
		install_dependencies()
	end

	local luarocks_dir = lfs.currentdir()
	local testing_dir = luarocks_dir .. "/new_test"
	src_dir = luarocks_dir .. "/src"
	local luarocks_temp = testing_dir .. "/luarocks-2.3.0"

	local testing_env_variables = {}
	luaversion_short = _VERSION:gsub("Lua ", "")

	local _, luaversion_full = execute("lua -v")
	luaversion_full = luaversion_full:gsub("(.*)%s(%d.%d.%d)%s(.*)", "%2")

	testing_lrprefix = testing_dir .. "/testing_lrprefix-" .. luaversion_full
	testing_tree = testing_dir .. "/testing-" .. luaversion_full
	testing_sys_tree = testing_dir .. "/testing_sys-" .. luaversion_full
	testing_tree_copy = testing_dir .. "/testing_copy-" .. luaversion_full
	testing_sys_tree_copy = testing_dir .. "/testing_sys_copy-" .. luaversion_full
	testing_cache = testing_dir .. "/testing_cache-" .. luaversion_full
	testing_server = testing_dir .. "/testing_server-" .. luaversion_full

	execute("mkdir " .. testing_cache)

--- CONFIG FILES
-- testing_config.lua and testing_config_show_downloads
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
    ["%{testing_sys_tree}"] = testing_sys_tree,
    ["%{testing_tree}"] = testing_tree,
    ["%{testing_server}"] = testing_server,
    ["%{testing_cache}"] = testing_cache})

	create_config(testing_dir .. "/testing_config.lua", config_content)
	create_config(testing_dir .. "/testing_config_show_downloads.lua", config_content .. "show_downloads = true")

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
    ["%{testing_sys_tree}"] = testing_sys_tree,
    ["%{testing_tree}"] = testing_tree,
    ["%{testing_cache}"] = testing_cache})

	create_config(testing_dir .. "/testing_config_sftp.lua", config_content)

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
    ["%{testing_dir}"] = testing_dir})

	create_config(testing_dir .. "/luacov.config", config_content)

	-- Export environment variables???
	testing_env_variables = {LUAROCKS_CONFIG=testing_dir .. "/testing_config.lua",LUA_PATH="",LUA_CPATH=""}

	-- TRAVIS TODO
	-- luadir = "/tmp/lua-" .. luaversion

	--LOCAL
	local luadir

	if lfs.attributes("/usr/bin/lua") then 
		luadir = "/usr"
	elseif lfs.attributes("/usr/local/bin/lua") then
		luadir = "/usr/local"
	end

	local lua = luadir .. "/bin/lua"

	local version_luasocket = "3.0rc1"
	local verrev_luasocket = version_luasocket .. "-1"
	local srcdir_luasocket = "luasocket-3.0-rc1"

	local version_cprint = "0.1"
	local verrev_cprint = "0.1-2"

	local new_version_say = "1.2-1"
	local old_version_say = "1.0-1"

	local version_luacov = "0.11.0"
	local verrev_luacov = version_luacov .. "-1"
	local version_lxsh = "0.8.6"
	local version_validate_args = "1.5.4"
	local verrev_validate_args = "1.5.4-1"
	local verrev_lxsh = version_lxsh .. "-2"
	local version_abelhas = "1.0"
	local verrev_abelhas = version_abelhas .. "-1"

	local luasec = "luasec"

	lfs.chdir(luarocks_dir)
	execute("./configure --with-lua=" .. luadir .. " --prefix=" .. testing_lrprefix .. " && make clean", false, testing_env_variables)
	execute("make src/luarocks/site_config.lua && make dev", false, testing_env_variables)
	lfs.chdir(src_dir)

	-- Main functions
	luarocks = function(cmd, env_variables) execute(lua .. " -e\"require('luacov.runner')('" .. dir .. "/luacov.config')'" .. src_dir .. "/bin/luarocks" .. cmd ..  "'\"", true, env_variables) end
	luarocks_nocov = function(cmd, env_variables) execute(lua .. " " .. src_dir .. "/bin/luarocks" .. cmd, true, env_variables) end
	luarocks_noprint= function(cmd, env_variables) execute(lua .. " " .. src_dir .. "/bin/luarocks" .. cmd, false, env_variables) end
	luarocks_noprint_nocov = function(cmd, env_variables) execute(lua .. " " .. src_dir .. "/bin/luarocks" .. cmd, false, env_variables) end
	luarocks_admin = function(cmd, env_variables) execute(lua .. " -e\"require('luacov.runner')('" .. dir .. "/luacov.config')'" .. src_dir .. "/bin/luarocks-admin" .. cmd ..  "'\"", true, env_variables) end
	luarocks_admin_nocov = function(cmd, env_variables) execute(lua .. " " .. src_dir .. "/bin/luarocks-admin" .. cmd, true, env_variables) end
	
	-- Download rocks and rockspecs for testing
	execute("mkdir " .. testing_server)
	lfs.chdir(testing_server)

	get_rocks("/luacov-" .. verrev_luacov .. ".src.rock")
	get_rocks("/luacov-" .. verrev_luacov .. ".rockspec")
	-- get_rocks("/luadoc-3.0.1-1.src.rock")
	-- get_rocks("/lualogging-1.3.0-1.src.rock")
	-- get_rocks("/luasocket-" .. verrev_luasocket .. ".src.rock")
	-- get_rocks("/luasocket-" .. verrev_luasocket .. ".rockspec")
	-- get_rocks("/luafilesystem-1.6.3-1.src.rock")
	-- get_rocks("/stdlib-41.0.0-1.src.rock")
	-- get_rocks("/luarepl-0.4-1.src.rock")
	-- get_rocks("/validate-args-1.5.4-1.rockspec")
	-- get_rocks("/luasec-0.6-1.rockspec")
	-- get_rocks("/luabitop-1.0.2-1.rockspec")
	-- get_rocks("/luabitop-1.0.2-1.src.rock")
	-- get_rocks("/lpty-1.0.1-1.src.rock")
	-- get_rocks("/cprint-" .. verrev_cprint .. ".src.rock")
	-- get_rocks("/cprint-" .. verrev_cprint .. ".rockspec")
	-- get_rocks("/wsapi-1.6-1.src.rock")
	-- get_rocks("/lxsh-" .. verrev_lxsh .. ".src.rock")
	-- get_rocks("/lxsh-" .. verrev_lxsh .. ".rockspec")
	-- get_rocks("/abelhas-" .. verrev_abelhas .. ".rockspec")
	-- get_rocks("/lzlib-0.4.1.53-1.src.rock")
	-- get_rocks("/lpeg-0.12-1.src.rock")
	-- get_rocks("/luaposix-33.2.1-1.src.rock")
	-- get_rocks("/md5-1.2-1.src.rock")
	-- get_rocks("/lmathx-20120430.51-1.src.rock")
	-- get_rocks("/lmathx-20120430.51-1.rockspec")
	-- get_rocks("/lmathx-20120430.52-1.src.rock")
	-- get_rocks("/lmathx-20120430.52-1.rockspec")
	-- get_rocks("/lmathx-20150505-1.src.rock")
	-- get_rocks("/lmathx-20150505-1.rockspec")
	-- get_rocks("/lua-path-0.2.3-1.src.rock")
	-- get_rocks("/lua-cjson-2.1.0-1.src.rock")
	-- get_rocks("/luacov-coveralls-0.1.1-1.src.rock")
	-- get_rocks("/say-1.2-1.src.rock")
	-- get_rocks("/say-1.0-1.src.rock")
	-- get_rocks("/luassert-1.7.0-1.src.rock")

	-- Preparation of environment to build
	luarocks_admin_nocov(" make_manifest " .. testing_server, testing_env_variables)
	local minimal_environment = {"luacov"}
	local full_environment = {}

	if luaversion_full == "5.1.5" then
		full_environment = {"luacov", "luafilesystem", "luasocket", "luabitop","luaposix", "md5", "lzlib"}
	else
		full_environment = {"luacov", "luafilesystem", "luasocket", "luaposix", "md5", "lzlib"}
	end

	-- Build environments
	build_environment(minimal_environment, testing_env_variables)
	-- build_environment(full_environment, testing_env_variables)

end

return test_enviroment