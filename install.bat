rem=rem --[[
@setlocal&  set luafile="%~f0" & if exist "%~f0.bat" set luafile="%~f0.bat"
@lua5.1\bin\lua5.1.exe %luafile% %*&  exit /b ]]

local vars = {}

vars.PREFIX = [[C:\LuaRocks]]
vars.VERSION = "2.1"
vars.SYSCONFDIR = [[C:\LuaRocks]]
vars.ROCKS_TREE = [[C:\LuaRocks]]
vars.SCRIPTS_DIR = nil
vars.LUA_INTERPRETER = nil
vars.LUA_PREFIX = nil
vars.LUA_BINDIR = nil
vars.LUA_INCDIR = nil
vars.LUA_LIBDIR = nil
vars.LUA_LIBNAME = nil
vars.LUA_VERSION = "5.1"
vars.LUA_SHORTV = nil
vars.LUA_LIB_NAMES = "lua5.1.lib lua51.dll liblua.dll.a"
vars.LUA_RUNTIME = nil

local P_SET = false
local FORCE = false
local FORCE_CONFIG = false
local INSTALL_LUA = false
local USE_MINGW = false
local REGISTRY = false

---
-- Some helpers
-- 
local function die(message)
	if message then print(message) end
	print()
	print("Failed installing LuaRocks. Run with /? for help.")
	os.exit(1)
end

local function exec(cmd)
	--print(cmd)
	local status = os.execute(cmd)
	return status == 0
end

local function exists(filename)
	local cmd = [[.\bin\test -e "]]..filename..[["]]
	return exec(cmd)
end

local function mkdir (dir)
	return exec([[.\bin\mkdir -p "]]..dir..[[" >NUL]])
end

-- interpolate string with values from 'vars' table
local function S (tmpl)
	return (tmpl:gsub('%$([%a_][%w_]*)', vars))
end

local function print_help()
	print(S[[
Installs LuaRocks.

/P [dir]       (REQUIRED) Where to install. 
               Note that version; $VERSION, will be
               appended to this path.
/CONFIG [dir]  Location where the config file should be installed.
               Default is same place of installation
/TREE [dir]    Root of the local tree of installed rocks.
               Default is same place of installation
/SCRIPTS [dir] Where to install scripts installed by rocks.
               Default is TREE/bin.

/LV [version]  Lua version to use; either 5.1 or 5.2.
               Default is 5.1
/L             Install LuaRocks' own copy of Lua even if detected,
               this will always be a 5.1 installation.
               (/LUA, /INC, /LIB, /BIN cannot be used with /L)
/LUA [dir]     Location where Lua is installed - e.g. c:\lua\5.1\
               This is the base directory, the installer will look
               for subdirectories bin, lib, include. Alternatively
               these can be specified explicitly using the /INC,
               /LIB, and /BIN options.
/INC [dir]     Location of Lua includes - e.g. c:\lua\5.1\include
               If provided overrides sub directory found using /LUA.
/LIB [dir]     Location of Lua libraries -e.g. c:\lua\5.1\lib
               If provided overrides sub directory found using /LUA.
/BIN [dir]     Location of Lua executables - e.g. c:\lua\5.1\bin
               If provided overrides sub directory found using /LUA.

/MW            Use mingw as build system instead of MSVC

/FORCECONFIG   Use a single config location. Do not use the
               LUAROCKS_CONFIG variable or the user's home directory.
               Useful to avoid conflicts when LuaRocks
               is embedded within an application.

/F             Remove installation directory if it already exists.

/R             Load registry information to register '.rockspec'
               extension with LuaRocks commands (right-click).

]])
end

-- ***********************************************************
-- Option parser
-- ***********************************************************
local function parse_options(args)
	for _, option in ipairs(args) do
		local name = option.name:upper()
		if name == "/?" then
			print_help()
			os.exit(0)
		elseif name == "/P" then
			vars.PREFIX = option.value
			vars.SYSCONFDIR = option.value
			vars.ROCKS_TREE = option.value
			P_SET = true
		elseif name == "/CONFIG" then
			vars.SYSCONFDIR = option.value
		elseif name == "/TREE" then
			vars.ROCKS_TREE = option.value
		elseif name == "/SCRIPTS" then
			vars.SCRIPTS_DIR = option.value
		elseif name == "/LV" then
			vars.LUA_VERSION = option.value
		elseif name == "/L" then
			INSTALL_LUA = true
		elseif name == "/MW" then
			USE_MINGW = true
		elseif name == "/LUA" then
			vars.LUA_PREFIX = option.value
		elseif name == "/LIB" then
			vars.LUA_LIBDIR = option.value
		elseif name == "/INC" then
			vars.LUA_INCDIR = option.value
		elseif name == "/BIN" then
			vars.LUA_BINDIR = option.value
		elseif name == "/FORCECONFIG" then
			FORCE_CONFIG = true
		elseif name == "/F" then
			FORCE = true
		elseif name == "/R" then
			REGISTRY = true
		else
			die("Unrecognized option: " .. name)
		end
	end
end

-- check for combination/required flags
local function check_flags()
	if not P_SET then
		die("Missing required parameter /P")
	end
	if INSTALL_LUA then
		if vars.LUA_INCDIR or vars.LUA_BINDIR or vars.LUA_LIBDIR or vars.LUA_PREFIX then
			die("Cannot combine option /L with any of /LUA /BIN /LIB /INC")
		end
		if vars.LUA_VERSION ~= "5.1" then
			die("Bundled Lua version is 5.1, cannot install 5.2")
		end
	end
	if vars.LUA_VERSION ~= "5.1" then
		if vars.LUA_VERSION == "5.2" then
			vars.LUA_LIB_NAMES = vars.LUA_LIB_NAMES:gsub("5([%.]?)1", "5%12")
		else
			die("Bad argument: /LV must either be 5.1 or 5.2")
		end
	end
end

-- ***********************************************************
-- Detect Lua
-- ***********************************************************
local function look_for_interpreter (directory)
	if vars.LUA_BINDIR then
		if exists( S"$LUA_BINDIR\\lua$LUA_VERSION.exe" ) then
			vars.LUA_INTERPRETER = S"lua$LUA_VERSION.exe"
			print(S"       Found $LUA_BINDIR\\$LUA_INTERPRETER")
			return true
		elseif exists(S"$LUA_BINDIR\\lua.exe") then
			vars.LUA_INTERPRETER = "lua.exe"
			print(S"       Found $LUA_BINDIR\\$LUA_INTERPRETER")
			return true
		elseif exists(S"$LUA_BINDIR\\luajit.exe") then
			vars.LUA_INTERPRETER = "luajit.exe"
			print(S"       Found $LUA_BINDIR\\$LUA_INTERPRETER")
			return true
		end
		die(S"Lua executable lua.exe, luajit.exe or lua$LUA_VERSION.exe not found in $LUA_BINDIR")
	end

	for _, e in ipairs{ [[\]], [[\bin\]] } do
		if exists(directory..e.."\\lua"..vars.LUA_VERSION..".exe") then
			vars.LUA_INTERPRETER = S"lua$LUA_VERSION.exe"
			vars.LUA_BINDIR = directory .. e
			print("       Found ."..e..vars.LUA_INTERPRETER)
			return true

		elseif exists(directory..e.."\\lua.exe") then
			vars.LUA_INTERPRETER = "lua.exe"
			vars.LUA_BINDIR = directory..e
			print("       Found ."..e..vars.LUA_INTERPRETER)
			return true

		elseif exists(directory..e.."\\luajit.exe") then
			vars.LUA_INTERPRETER = "luajit.exe"
			vars.LUA_BINDIR = directory..e
			print("       Found ."..e..vars.LUA_INTERPRETER)
			return true
		end
	end
	print("      No Lua interpreter found")
	return false
end

local function look_for_link_libraries (directory)
	if vars.LUA_LIBDIR then
		for name in vars.LUA_LIB_NAMES:gmatch("[^%s]+") do
			print(S"    checking for $LUA_LIBDIR\\"..name)
			if exists(vars.LUA_LIBDIR.."\\"..name) then
				vars.LUA_LIBNAME = name
				print("       Found "..name)
				return true
			end
		end
		die(S"link library (one of; $LUA_LIB_NAMES) not found in $LUA_LIBDIR")
	end

	for _, e in ipairs{ [[\]], [[\lib\]], [[\bin\]]} do
		for name in vars.LUA_LIB_NAMES:gmatch("[^%s]+") do
			print("    checking for "..directory..e.."\\"..name)
			if exists(directory..e.."\\"..name) then
				vars.LUA_LIBDIR = directory .. e
				vars.LUA_LIBNAME = name
				print("       Found "..name)
				return true
			end
		end
	end
	return false
end

local function look_for_headers (directory)
	if vars.LUA_INCDIR then
		print(S"    checking for $LUA_INCDIR\\lua.h")
		if exists(S"$LUA_INCDIR\\lua.h") then
			print("       Found lua.h")
			return true
		end
		die(S"lua.h not found in $LUA_INCDIR")
	end

	for _, e in ipairs{ [[\]], [[\include\]]} do
		print("    checking for "..directory..e.."\\lua.h")
		if exists(directory..e.."\\lua.h") then
			vars.LUA_INCDIR = directory..e
			print("       Found lua.h")
			return true
		end
	end
	return false
end

-- Checks a binary file for the runtime dll used by it. If nu runtime is found, it returns an
-- array of dll's is depends upon.
-- result: string = runtime used, table = list of dll's depended upon, nil = nothing found.
local function get_file_runtime(p,f) -- path, filename
	local infile = p.."\\"..f
	local outfile = "output.txt"
	local content
	-- analyze binary
	if exec([[.\bin\objdump -x "]]..infile..[[" > ]]..outfile..[[ 2<&1]]) then
		-- read temp file
		local fh = io.open(outfile)
		content = fh:read("*a")
		fh:close()
	end
	-- delete temp file
	os.remove(outfile)
	if not content then
		print("    Failed to analyze "..infile.." for the runtime used")
        return nil
    end

	-- lookup
	content = content:upper()
	local result = content:match('DLL NAME%: (MSVCR%d*)%.DLL')
	if not result then
	  result = content:match('DLL NAME%: (MSVCRT)%.DLL')
	end

	if result then
		print("    "..f.." uses "..tostring(result)..".DLL as runtime")
	else
		print("    No runtime found for "..f)
		-- so; create a list of dll's this file is depending upon, next level of the tree
		result = {}
		for name in content:gmatch("DLL NAME%: (.-%.DLL)") do
			--print("found dll:", name)
			table.insert(result, name)
		end
	end
	return result
end

local function get_runtime()
	-- first check interpreter
	vars.LUA_RUNTIME = get_file_runtime(vars.LUA_BINDIR, vars.LUA_INTERPRETER)
	if type(vars.LUA_RUNTIME) == "table" then
		-- a table with dll's depended upon was returned, check this list
		-- note: we only check 1 level deep
		for _,dll in ipairs(vars.LUA_RUNTIME) do
			local t = get_file_runtime(vars.LUA_BINDIR, dll)
			if type(t) == "string" then
				-- found it
				vars.LUA_RUNTIME = t
				break
			end
		end
	end
	if type(vars.LUA_RUNTIME) ~= "string" then
		-- analysis failed, issue a warning
		vars.LUA_RUNTIME = "MSVCR80"
		print("*** WARNING ***: could not analyse the runtime used, defaulting to "..vars.LUA_RUNTIME)
	end
	return true
end

local function look_for_lua_install ()
	print("Looking for Lua interpreter")
	local directories = { [[c:\lua5.1.2]], [[c:\lua]], [[c:\kepler\1.1]] }
	if vars.LUA_PREFIX then
		table.insert(directories, 1, vars.LUA_PREFIX)
	end
	if vars.LUA_BINDIR and vars.LUA_LIBDIR and vars.LUA_INCDIR then
		if look_for_interpreter(vars.LUA_BINDIR) and 
			look_for_link_libraries(vars.LUA_LIBDIR) and
			look_for_headers(vars.LUA_INCDIR)
		then
			if get_runtime() then
				print("Runtime check completed, now testing interpreter...")
				if exec(S[[$LUA_BINDIR\$LUA_INTERPRETER -v 2>NUL]]) then
					print("    Ok")
					return true
				end
				print("   Interpreter returned an error, not ok")
			end
		end
		return false
	end
	
	for _, directory in ipairs(directories) do
		print("    checking " .. directory)
		if exists(directory) then
			if look_for_interpreter(directory) then
				print("Interpreter found, now looking for link libraries...")
				if look_for_link_libraries(directory) then
					print("Link library found, now looking for headers...")
					if look_for_headers(directory) then
						print("Headers found, checking runtime to use...")
						if get_runtime() then
							print("Runtime check completed, now testing interpreter...")
							if exec(S[[$LUA_BINDIR\$LUA_INTERPRETER -v 2>NUL]]) then
								print("    Ok")
								return true
							end
							print("   Interpreter returned an error, not ok")
						end
					end
				end
			end
		end
	end
	return false
end

---
-- Poor man's command-line parsing
local config = {}
local with_arg = { -- options followed by an argument, others are flags
	["/P"] = true,
	["/CONFIG"] = true,
	["/TREE"] = true,
	["/SCRIPTS"] = true,
	["/LV"] = true,
	["/LUA"] = true,
	["/INC"] = true,
	["/BIN"] = true,
	["/LIB"] = true,
}
local i = 1
while i <= #arg do
	local opt = arg[i]
	if with_arg[opt] then
		local value = arg[i + 1]
		if not value then
			die("Missing value for option "..opt)
		end
		config[#config + 1] = { name = opt, value = value }
		i = i + 1
	else
		config[#config + 1] = { name = opt }
	end
	i = i + 1
end

print(S"LuaRocks $VERSION.x installer.\n")

parse_options(config)
check_flags()

vars.FULL_PREFIX = S"$PREFIX\\$VERSION"
vars.BINDIR = vars.FULL_PREFIX
vars.LIBDIR = vars.FULL_PREFIX
vars.LUADIR = S"$FULL_PREFIX\\lua"
vars.INCDIR = S"$FULL_PREFIX\\include"
vars.LUA_SHORTV = vars.LUA_VERSION:gsub("%.", "")

if not look_for_lua_install() then
	print("Could not find Lua. Will install its own copy.")
	print("See /? for options for specifying the location of Lua.")
	if vars.LUA_VERSION ~= "5.1" then
		die("Cannot install own copy because no 5.2 version is bundled")
	end
	INSTALL_LUA = true
	vars.LUA_INTERPRETER = "lua5.1"
	vars.LUA_BINDIR = vars.BINDIR
	vars.LUA_LIBDIR = vars.LIBDIR
	vars.LUA_INCDIR = vars.INCDIR
	vars.LUA_LIBNAME = "lua5.1.lib"
    vars.LUA_RUNTIME = "MSVCR80"
else
	print(S[[

Will configure LuaRocks with the following paths:
LuaRocks       : $FULL_PREFIX
Lua interpreter: $LUA_BINDIR\$LUA_INTERPRETER
Lua binaries   : $LUA_BINDIR
Lua libraries  : $LUA_LIBDIR
Lua includes   : $LUA_INCDIR
Binaries will be linked against: $LUA_LIBNAME with runtime $LUA_RUNTIME

]])
end

-- ***********************************************************
-- Install LuaRocks files
-- ***********************************************************
if FORCE then
	print(S"Removing $FULL_PREFIX...")
	exec(S[[RD /S /Q "$FULL_PREFIX"]])
	print()
end

if exists(vars.FULL_PREFIX) then
	die(S"$FULL_PREFIX exists. Use /F to force removal and reinstallation.")
end

print(S"Installing LuaRocks in $FULL_PREFIX...")
if not exists(vars.BINDIR) then
	if not mkdir(vars.BINDIR) then
		die()
	end
end

if INSTALL_LUA then
	-- Copy the included Lua interpreter binaries
	if not exists(vars.LUA_BINDIR) then
		mkdir(vars.LUA_BINDIR)
	end
	if not exists(vars.LUA_INCDIR) then
		mkdir(vars.LUA_INCDIR)
	end
	exec(S[[COPY lua5.1\bin\*.* "$LUA_BINDIR" >NUL]])
	exec(S[[COPY lua5.1\include\*.* "$LUA_INCDIR" >NUL]])
	print(S"Installed the LuaRocks bundled Lua interpreter in $LUA_BINDIR")
end

-- Copy the LuaRocks binaries
if not exec(S[[COPY bin\*.* "$BINDIR" >NUL]]) then
	die()
end
-- Copy the LuaRocks lua source files
if not exists(S[[$LUADIR\luarocks]]) then
	if not mkdir(S[[$LUADIR\luarocks]]) then
		die()
	end
end
if not exec(S[[XCOPY /S src\luarocks\*.* "$LUADIR\luarocks" >NUL]]) then
	die()
end
-- Create start scripts
if not exec(S[[COPY src\bin\*.* "$BINDIR" >NUL]]) then
	die()
end
for _, c in ipairs{"luarocks", "luarocks-admin"} do
	-- rename unix-lua scripts to .lua files
	if not exec( (S[[RENAME "$BINDIR\%s" %s.lua]]):format(c, c) ) then
		die()
	end
	-- create a bootstrap batch file for the lua file, to start them
	exec(S[[DEL /F /Q "$BINDIR\]]..c..[[.bat" 2>NUL]])
	local f = io.open(vars.BINDIR.."\\"..c..".bat", "w")
	f:write(S[[
@ECHO OFF
SETLOCAL
SET LUA_PATH=$LUADIR\?.lua;$LUADIR\?\init.lua;%LUA_PATH%
SET PATH=$BINDIR\;%PATH%
"$LUA_INTERPRETER" "$BINDIR\]]..c..[[.lua" %*
ENDLOCAL
]])
	f:close()
	print(S"Created LuaRocks command: $BINDIR\\"..c..".bat")
end
-- configure 'scripts' directory
if vars.SCRIPTS_DIR then
	mkdir(vars.SCRIPTS_DIR)
	if not USE_MINGW then
		-- definitly not for MinGW because of conflicting runtimes
		-- but is it ok to do it for others???
		exec(S[[COPY lua5.1\bin\*.dll "$SCRIPTS_DIR" >NUL]])
	end
else
	if not USE_MINGW then
	mkdir(S[[$ROCKS_TREE\bin]])
		-- definitly not for MinGW because of conflicting runtimes
		-- but is it ok to do it for others???
		exec(S[[COPY lua5.1\bin\*.dll "$ROCKS_TREE"\bin >NUL]])
	end
end


print()
print("Configuring LuaRocks...")
-- Create a site-config file
if exists(S[[$LUADIR\luarocks\site_config.lua]]) then
	exec(S[[RENAME "$LUADIR\luarocks\site_config.lua" site_config.lua.bak]])
end
local f = io.open(vars.LUADIR.."\\luarocks\\site_config.lua", "w")
f:write(S[=[
module("luarocks.site_config")
LUA_INCDIR=[[$LUA_INCDIR]]
LUA_LIBDIR=[[$LUA_LIBDIR]]
LUA_BINDIR=[[$LUA_BINDIR]]
LUA_INTERPRETER=[[$LUA_INTERPRETER]]
]=])
if USE_MINGW then
	f:write("LUAROCKS_UNAME_S=[[MINGW]]\n")
else
	f:write("LUAROCKS_UNAME_S=[[WindowsNT]]\n")
end
f:write(S[=[
LUAROCKS_UNAME_M=[[x86]]
LUAROCKS_SYSCONFIG=[[$SYSCONFDIR\config.lua]]
LUAROCKS_ROCKS_TREE=[[$ROCKS_TREE]]
LUAROCKS_PREFIX=[[$PREFIX]]
LUAROCKS_DOWNLOADER=[[wget]]
LUAROCKS_MD5CHECKER=[[md5sum]]
]=])
if FORCE_CONFIG then
	f:write("local LUAROCKS_FORCE_CONFIG=true\n")
end
if exists(vars.LUADIR.."\\luarocks\\site_config.lua.bak") then
	for line in io.lines(vars.LUADIR.."\\luarocks\\site_config.lua.bak", "r") do
		f:write(line)
		f:write("\n")
	end
	exec(S[[DEL /F /Q "$LUADIR\luarocks\site_config.lua.bak"]])
end
f:close()
print(S[[Created LuaRocks site-config file: $LUADIR\luarocks\site_config.lua]])

-- create config file
vars.CONFIG_FILE = vars.SYSCONFDIR.."\\config.lua"
if not exists(vars.SYSCONFDIR) then
	mkdir(vars.SYSCONFDIR)
end
if not exists(vars.CONFIG_FILE) then
	local f = io.open(vars.CONFIG_FILE, "w")
	f:write([=[
rocks_servers = {
   [[http://luarocks.org/repositories/rocks]]
}
rocks_trees = {
]=])
	if FORCE_CONFIG then
		f:write("    home..[[/luarocks]],\n")
	end
	f:write(S"    [[$ROCKS_TREE]]\n")
	f:write("}\n")
	if vars.SCRIPTS_DIR then
		f:write(S"scripts_dir=[[$SCRIPTS_DIR]]\n")
	end
	f:write("variables = {\n")
	if USE_MINGW and vars.LUA_RUNTIME == "MSVCRT" then
		f:write("    MSVCRT = 'm',   -- make MinGW use MSVCRT.DLL as runtime\n")
	else
		f:write("    MSVCRT = '"..vars.LUA_RUNTIME.."',\n")
	end
	f:write(S"    LUALIB = '$LUA_LIBNAME'\n")
	f:write("}\n")
	f:close()
	print(S"Created LuaRocks config file: $CONFIG_FILE")
else
	print(S"LuaRocks config file already exists: $CONFIG_FILE")
end

print()
print("Creating rocktrees...")
if not exists(vars.ROCKS_TREE) then
	mkdir(vars.ROCKS_TREE)
	print(S[[Created rocktree: "$ROCKS_TREE"]])
else
	print(S[[Rocktree exists: "$ROCKS_TREE"]])
end
local APPDATA = os.getenv("APPDATA")
if not exists(APPDATA.."\\luarocks") then
	mkdir(APPDATA.."\\luarocks")
	print([[Created rocktree: "]]..APPDATA..[[\luarocks"]])
else
	print([[Rocktree exists: "]]..APPDATA..[[\luarocks"]])
end

-- Load registry information
if REGISTRY then
	-- expand template with correct path information
	print()
	print([[Loading registry information for ".rockspec" files]])
	exec( S[[lua5.1\bin\lua5.1.exe "$FULL_PREFIX\create_reg_file.lua" "$FULL_PREFIX\LuaRocks.reg.template"]] )
	exec( S"$FULL_PREFIX\\LuaRocks.reg" )
end

-- ***********************************************************
-- Exit handlers 
-- ***********************************************************

print(S[[
*** LuaRocks is installed! ***

 You may want to add the following elements to your paths;
PATH     :   $LUA_BINDIR;$FULL_PREFIX
LUA_PATH :   $ROCKS_TREE\share\lua\$LUA_VERSION\?.lua;$ROCKS_TREE\share\lua\$LUA_VERSION\?\init.lua
LUA_CPATH:   $LUA_LIBDIR\lua\$LUA_VERSION\?.dll

]])
os.exit(0)
