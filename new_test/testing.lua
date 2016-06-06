#!/usr/bin/env lua
local test_environment = require("./test_environment")

local arg = arg or { ... }

if arg[1] == nil then
	print("LuaRocks test-suite\n\n"..
		[[
INFORMATION
	Lua isntalled and added to path needed. 

USAGE
	--lua <version> (mandatory) type your full version of Lua (e.g. --lua 5.2.4)
	--env <type> 	(default:"minimal") type what kind of environment to use ["minimal", "full"]
	--clean 	remove existing testing environment
	--os <version> 	type your OS ["linux", "os x", "windows"]
		]]);
	return
end

local env_variables = {}
env_variables.TYPE_TEST_ENV = "minimal"

for i=1, #arg do
	if arg[i] == "--lua" then
		env_variables.LUA_V = arg[i+1]
	end
	if arg[i] == "--env" then
		env_variables.TYPE_TEST_ENV = arg[i+1]
	end
	if arg[i] == "--clean" then
		env_variables.TEST_CLEAN = "yes"
	end
	if arg[i] == "--os" then
		env_variables.TEST_TARGET_OS = arg[i+1]
	end
end

if not env_variables.TEST_TARGET_OS then
	print("OS check")
	local testing_os
	if test_environment.execute_bool("sw_vers") then 
		env_variables.TEST_TARGET_OS = "os x"
	elseif test_environment.execute_bool("uname -s") then
		env_variables.TEST_TARGET_OS = "linux"
	else
		env_variables.TEST_TARGET_OS = "windows"
	end
end

-- Run Busted to perform tests
test_environment.execute_bool("busted -C \"../\" -t \"install_blackbox\" ", true, env_variables)