local fs = require("luarocks.fs")

local test_enviroment = {}

function test_enviroment.run (...) 
	local luarocks_dir = fs.current_dir()
	local testing_dir = luarocks_dir .. "/new_test"
	local src_dir = luarocks_dir .. "/src"

	local luaversion = _VERSION:gsub("Lua ", "")

	testing_lrprefix = testing_dir .. "/testing_lrprefix-" .. luaversion
	testing_tree = testing_dir .. "/testing-" .. luaversion
	testing_sys_tree =  testing_dir .. "/testing_sys-" .. luaversion
	testing_tree_copy =  testing_dir .. "/testing_copy-" .. luaversion
	testing_sys_tree_copy =  testing_dir .. "/testing_sys_copy-" .. luaversion
	testing_cache =  testing_dir .. "/testing_cache-" .. luaversion
	testing_server =  testing_dir .. "/testing_server-" .. luaversion

	-- TRAVIS TODO
	-- luadir = "/tmp/lua-" .. luaversion

	--LOCAL
	local luadir

	if fs.exists("/usr/bin/lua") then 
		luadir = "/usr"
	elseif fs.exists("/usr/bin/lua") then
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


	fs.change_dir(luarocks_dir)
	os.execute("./configure --with-lua=" .. luadir .. " --prefix=" .. testing_lrprefix .. " && make clean")
	os.execute("make src/luarocks/site_config.lua && make dev")
	fs.change_dir(src_dir)

	--TODO
	function run_lua(cmd, ...)
		-- os.execute( lua .. " -e \"require('luacov.runner')(" .. testing_dir .. "/luacov.config)(" .. src_dir .. "/bin/" .. cmd .. ")\"  ")
		-- lua
	end
	-- run_lua("--no-cov", "luarocks")

	function build_environment () 

	end
	--TODO

	-- version_luacov=0.11.0
	-- verrev_luacov=${version_luacov}-1

	-- os.execute("mkdir " .. testing_server)

	-- luarocks_repo = "https://luarocks.org"
	--  [ -e `basename "$1"` ] || wget -c "$1"; }
	-- luarocks_repo .. "/luacov-" .. verrev_luacov .. ".src.rock"

	-- "https://luarocks.org/luacov-0.11.0-1.src.rock"
end

return test_enviroment