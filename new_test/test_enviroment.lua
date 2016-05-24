local lfs

local test_enviroment = {}

-- Install required dependencies with LuaRocks stable
local function install_dependencies()
	print("Checking if LuaRocks is installed")
	if os.execute("luarocks --version") then 
		print("LuaRocks detected\n")
	else
		print("LuaRocks not detected, installing...")
		os.execute("wget -cP ./new_test http://luarocks.org/releases/luarocks-2.3.0.tar.gz")
		os.execute("tar zxpf ./new_test/luarocks-2.3.0.tar.gz -C ./new_test/")
		os.execute("rm ./new_test/luarocks-2.3.0.tar.gz")
		os.execute("./new_test/luarocks-2.3.0/configure; sudo make bootstrap ./new_test/luarocks-2.3.0/")
		os.execute("rm -rf ./new_test/luarocks-2.3.0/")
	end

	print("Checking if Busted is installed")
	if os.execute("busted --version") then 
		print("Busted detected\n")
	else
		print("Busted not detected, installing...")
		os.execute("luarocks install busted")
	end

	lfs = require("lfs")
end 

-- Function for downloading rocks and rockspecs
local function get_rocks(rock)
	local luarocks_repo = "https://luarocks.org"
	if not lfs.attributes(rock) then 
		os.execute("wget -c " .. luarocks_repo .. rock)	
	end
end

function test_enviroment.run(...)

	if os.execute("echo 'LuaRocks version:' && luarocks --version") and os.execute("echo 'Busted version:' && busted --version") then
		lfs = require("lfs") 
	else
		install_dependencies()
	end

	local luarocks_dir = lfs.currentdir()
	local testing_dir = luarocks_dir .. "/new_test"
	local src_dir = luarocks_dir .. "/src"
	local luarocks_temp = testing_dir .. "/luarocks-2.3.0"

	local luaversion = _VERSION:gsub("Lua ", "")


	testing_lrprefix = testing_dir .. "/testing_lrprefix-" .. luaversion
	testing_tree = testing_dir .. "/testing-" .. luaversion
	testing_sys_tree = testing_dir .. "/testing_sys-" .. luaversion
	testing_tree_copy = testing_dir .. "/testing_copy-" .. luaversion
	testing_sys_tree_copy = testing_dir .. "/testing_sys_copy-" .. luaversion
	testing_cache = testing_dir .. "/testing_cache-" .. luaversion
	testing_server = testing_dir .. "/testing_server-" .. luaversion

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
	os.execute("./configure --with-lua=" .. luadir .. " --prefix=" .. testing_lrprefix .. " && make clean")
	os.execute("make src/luarocks/site_config.lua && make dev")
	lfs.chdir(src_dir)


	-- --TODO
	-- function run_lua(cmd, params)
	-- 	local params = params or ""

	-- 	if 
	-- 		os.execute(lua .. " -e \"require('luacov.runner')('" .. testing_dir .. "/luacov.config') '" .. src_dir .. "/bin/" .. cmd .. " " .. params ..  "'\"")
		
	-- 		os.execute(lua .. " " .. src_dir .. "/bin/" .. "luarocks " .. params)
	-- 	end
	-- end

	-- luarocks = run_lua("luarocks")
	-- luarocks_nocov = run_lua("luarocks", "--nocov")
	-- luarocks_noecho= run_lua("luarocks", "--noecho")
	-- luarocks_noecho_nocov = run_lua("luarocks", "--noecho --nocov")
	-- luarocks_admin = run_lua("luarocks-admin")
	-- luarocks_admin_nocov = run_lua("luarocks-admin", "--nocov")

	--TODO

	-- version_luacov=0.11.0
	-- verrev_luacov=${version_luacov}-1

	os.execute("mkdir " .. testing_server)
	lfs.chdir(testing_server)

	get_rocks("/luacov-" .. verrev_luacov .. ".src.rock")
	get_rocks("/luacov-" .. verrev_luacov .. ".rockspec")
	get_rocks("/luadoc-3.0.1-1.src.rock")
	get_rocks("/lualogging-1.3.0-1.src.rock")
	get_rocks("/luasocket-" .. verrev_luasocket .. ".src.rock")
	get_rocks("/luasocket-" .. verrev_luasocket .. ".rockspec")
	get_rocks("/luafilesystem-1.6.3-1.src.rock")
	get_rocks("/stdlib-41.0.0-1.src.rock")
	get_rocks("/luarepl-0.4-1.src.rock")
	get_rocks("/validate-args-1.5.4-1.rockspec")
	get_rocks("/luasec-0.6-1.rockspec")
	get_rocks("/luabitop-1.0.2-1.rockspec")
	get_rocks("/luabitop-1.0.2-1.src.rock")
	get_rocks("/lpty-1.0.1-1.src.rock")
	get_rocks("/cprint-" .. verrev_cprint .. ".src.rock")
	get_rocks("/cprint-" .. verrev_cprint .. ".rockspec")
	get_rocks("/wsapi-1.6-1.src.rock")
	get_rocks("/lxsh-" .. verrev_lxsh .. ".src.rock")
	get_rocks("/lxsh-" .. verrev_lxsh .. ".rockspec")
	get_rocks("/abelhas-" .. verrev_abelhas .. ".rockspec")
	get_rocks("/lzlib-0.4.1.53-1.src.rock")
	get_rocks("/lpeg-0.12-1.src.rock")
	get_rocks("/luaposix-33.2.1-1.src.rock")
	get_rocks("/md5-1.2-1.src.rock")
	get_rocks("/lmathx-20120430.51-1.src.rock")
	get_rocks("/lmathx-20120430.51-1.rockspec")
	get_rocks("/lmathx-20120430.52-1.src.rock")
	get_rocks("/lmathx-20120430.52-1.rockspec")
	get_rocks("/lmathx-20150505-1.src.rock")
	get_rocks("/lmathx-20150505-1.rockspec")
	get_rocks("/lua-path-0.2.3-1.src.rock")
	get_rocks("/lua-cjson-2.1.0-1.src.rock")
	get_rocks("/luacov-coveralls-0.1.1-1.src.rock")
	get_rocks("/say-1.2-1.src.rock")
	get_rocks("/say-1.0-1.src.rock")
	get_rocks("/luassert-1.7.0-1.src.rock")

	-- TODO
	function build_environment () 
		os.execute("rm -rf " .. testing_tree)
		os.execute("rm -rf " .. testing_sys_tree)
		os.execute("rm -rf " .. testing_tree_copy)
		os.execute("rm -rf " .. testing_sys_tree_copy)
   
   	os.execute("mkdir " .. testing_tree)
   	os.execute("mkdir " .. testing_sys_tree)
	end

end

return test_enviroment