rem=rem --[[
@setlocal&  set luafile="%~f0" & if exist "%~f0.bat" set luafile="%~f0.bat"
@win32\lua5.1\bin\lua5.1.exe %luafile% %*&  exit /b ]]

local vars = {}


vars.PREFIX = nil
vars.VERSION = "2.2"
vars.SYSCONFDIR = nil
vars.TREE_ROOT = nil
vars.TREE_BIN = nil
vars.TREE_LMODULE = nil
vars.TREE_CMODULE = nil
vars.LUA_INTERPRETER = nil
vars.LUA_PREFIX = nil
vars.LUA_BINDIR = nil
vars.LUA_INCDIR = nil
vars.LUA_LIBDIR = nil
vars.LUA_LIBNAME = nil
vars.LUA_VERSION = "5.1"
vars.LUA_SHORTV = nil   -- "51"
-- MinGW does not generate .lib, nor needs it to link, but MSVC does
-- so .lib must be listed first to ensure they are found first if present.
-- To prevent MSVC trying to link to a .dll, which won't work.
vars.LUA_LIB_NAMES = "lua5.1.lib lua51.lib lua5.1.dll lua51.dll liblua.dll.a"
vars.LUA_RUNTIME = nil
vars.UNAME_M = nil

local FORCE = false
local FORCE_CONFIG = false
local INSTALL_LUA = false
local USE_MINGW = false
local REGISTRY = true
local NOADMIN = false
local PROMPT = true
local SELFCONTAINED = false

---
-- Some helpers
-- 

local pe = assert(loadfile(".\\win32\\pe-parser.lua"))()

local function die(message)
	if message then print(message) end
	print()
	print("Failed installing LuaRocks. Run with /? for help.")
	os.exit(1)
end

function split_string(str, delim, maxNb)
	-- Eliminate bad cases...
	if string.find(str, delim) == nil then
		return { str }
	end
	if maxNb == nil or maxNb < 1 then
		maxNb = 0	 -- No limit
	end
	local result = {}
	local pat = "(.-)" .. delim .. "()"
	local nb = 0
	local lastPos
	for part, pos in string.gmatch(str, pat) do
		nb = nb + 1
		result[nb] = part
		lastPos = pos
		if nb == maxNb then break end
	end
	-- Handle the last field
	if nb ~= maxNb then
		result[nb + 1] = string.sub(str, lastPos)
	end
	return result
end


local function exec(cmd)
	--print(cmd)
	local status = os.execute(cmd)
	return (status == 0 or status == true) -- compat 5.1/5.2
end

local function exists(filename)
	local cmd = [[.\win32\tools\test -e "]]..filename..[["]]
	return exec(cmd)
end

local function mkdir (dir)
	return exec([[.\win32\tools\mkdir -p "]]..dir..[[" >NUL]])
end

-- does the current user have admin priviledges ( = elevated)
local function permission()
	return exec("net session >NUL 2>&1") -- fails if not admin
end

-- rename file (full path) to backup (name only), appending number if required
-- returns the new name (name only)
local function backup(filename, backupname)
	local path = filename:match("(.+)%\\.-$").."\\"
	local nname = backupname
	local i = 0
	while exists(path..nname) do
		i = i + 1
		nname = backupname..tostring(i)
	end
	exec([[REN "]]..filename..[[" "]]..nname..[[" > NUL]])
	return nname
end

-- interpolate string with values from 'vars' table
local function S (tmpl)
	return (tmpl:gsub('%$([%a_][%w_]*)', vars))
end

local function print_help()
	print(S[[
Installs LuaRocks.

/P [dir]       Where to install LuaRocks. 
               Note that version; $VERSION, will be appended to this
               path, so "/P c:\luarocks\" will install in 
               "c:\luarocks\$VERSION\"
               Default is %PROGRAMFILES%\LuaRocks

Configuring the destinations:
/TREE [dir]    Root of the local tree of installed rocks.
               Default is %PROGRAMFILES%\LuaRocks\systree
/SCRIPTS [dir] Where to install commandline scripts installed by
               rocks. Default is {TREE}\bin.
/LUAMOD [dir]  Where to install Lua modules installed by rocks.
               Default is {TREE}\share\lua\{LV}.
/CMOD [dir]    Where to install c modules installed by rocks.
               Default is {TREE}\lib\lua\{LV}.
/CONFIG [dir]  Location where the config file should be installed.
               Default is to follow /P option
/SELFCONTAINED Creates a self contained installation in a single
               directory given by /P.
               Sets the /TREE and /CONFIG options to the same 
               location as /P. And does not load registry info
               with option /NOREG. The only option NOT self
               contained is the user rock tree, so don't use that
               if you create a self contained installation.
               
Configuring the Lua interpreter:
/LV [version]  Lua version to use; either 5.1, 5.2, or 5.3.
               Default is 5.1
/LUA [dir]     Location where Lua is installed - e.g. c:\lua\5.1\
               If not provided, the installer will search the system
               path and some default locations for a valid Lua
               installation.
               This is the base directory, the installer will look
               for subdirectories bin, lib, include. Alternatively
               these can be specified explicitly using the /INC,
               /LIB, and /BIN options.
/INC [dir]     Location of Lua includes - e.g. c:\lua\5.1\include
               If provided overrides sub directory found using /LUA.
/LIB [dir]     Location of Lua libraries (.dll/.lib) - e.g. c:\lua\5.1\lib
               If provided overrides sub directory found using /LUA.
/BIN [dir]     Location of Lua executables - e.g. c:\lua\5.1\bin
               If provided overrides sub directory found using /LUA.
/L             Install LuaRocks' own copy of Lua even if detected,
               this will always be a 5.1 installation.
               (/LUA, /INC, /LIB, /BIN cannot be used with /L)

Compiler configuration:
/MW            Use mingw as build system instead of MSVC

Other options:
/FORCECONFIG   Use a single config location. Do not use the
               LUAROCKS_CONFIG variable or the user's home directory.
               Useful to avoid conflicts when LuaRocks
               is embedded within an application.
/F             Remove installation directory if it already exists.
/NOREG         Do not load registry info to register '.rockspec'
               extension with LuaRocks commands (right-click).
/NOADMIN       The installer requires admin priviledges. If not
               available it will elevate a new process. Use this
               switch to prevent elevation, but make sure the
               destination paths are all accessible for the current
               user.
/Q             Do not prompt for confirmation of settings

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
		elseif name == "/CONFIG" then
			vars.SYSCONFDIR = option.value
		elseif name == "/TREE" then
			vars.TREE_ROOT = option.value
		elseif name == "/SCRIPTS" then
			vars.TREE_BIN = option.value
		elseif name == "/LUAMOD" then
			vars.TREE_LMODULE = option.value
		elseif name == "/CMOD" then
			vars.TREE_CMODULE = option.value
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
		elseif name == "/SELFCONTAINED" then
			SELFCONTAINED = true
		elseif name == "/NOREG" then
			REGISTRY = false
		elseif name == "/NOADMIN" then
			NOADMIN = true
		elseif name == "/Q" then
			PROMPT = false
		else
			die("Unrecognized option: " .. name)
		end
	end
end

-- check for combination/required flags
local function check_flags()
	if SELFCONTAINED then
		if not vars.PREFIX then
			die("Option /P is required when using /SELFCONTAINED")
		end
		if vars.SYSCONFDIR or vars.TREE_ROOT or vars.TREE_BIN or vars.TREE_LMODULE or vars.TREE_CMODULE then
			die("Cannot combine /TREE, /SCRIPTS, /LUAMOD, /CMOD, or /CONFIG with /SELFCONTAINED")
		end
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
		elseif vars.LUA_VERSION == "5.3" then
			vars.LUA_LIB_NAMES = vars.LUA_LIB_NAMES:gsub("5([%.]?)1", "5%13")
		else
			die("Bad argument: /LV must either be 5.1, 5.2, or 5.3")
		end
	end
end

-- ***********************************************************
-- Detect Lua
-- ***********************************************************
local function look_for_interpreter (directory)
	if vars.LUA_BINDIR then
        -- if LUA_BINDIR is specified, it must be there, otherwise we fail
		if exists( S"$LUA_BINDIR\\lua$LUA_VERSION.exe" ) then
			vars.LUA_INTERPRETER = S"lua$LUA_VERSION.exe"
			print(S"       Found $LUA_BINDIR\\$LUA_INTERPRETER")
			return true
		elseif exists( S"$LUA_BINDIR\\lua$LUA_SHORTV.exe" ) then
			vars.LUA_INTERPRETER = S"lua$LUA_SHORTV.exe"
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
		die(S"Lua executable lua.exe, luajit.exe, lua$LUA_SHORTV.exe or lua$LUA_VERSION.exe not found in $LUA_BINDIR")
	end

	for _, e in ipairs{ [[\]], [[\bin\]] } do
		if exists(directory..e.."\\lua"..vars.LUA_VERSION..".exe") then
			vars.LUA_INTERPRETER = S"lua$LUA_VERSION.exe"
			vars.LUA_BINDIR = directory .. e
			print("       Found ."..e..vars.LUA_INTERPRETER)
			return true

		elseif exists(directory..e.."\\lua"..vars.LUA_SHORTV..".exe") then
			vars.LUA_INTERPRETER = S"lua$LUA_SHORTV.exe"
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


local function get_runtime()
	local f
	vars.LUA_RUNTIME, f = pe.msvcrt(vars.LUA_BINDIR.."\\"..vars.LUA_INTERPRETER)
	if type(vars.LUA_RUNTIME) ~= "string" then
		-- analysis failed, issue a warning
		vars.LUA_RUNTIME = "MSVCR80"
		print("*** WARNING ***: could not analyse the runtime used, defaulting to "..vars.LUA_RUNTIME)
	else
		print("    "..f.." uses "..vars.LUA_RUNTIME..".DLL as runtime")
	end
	return true
end

local function get_architecture()
	-- detect processor arch interpreter was compiled for
	local proc = (pe.parse(vars.LUA_BINDIR.."\\"..vars.LUA_INTERPRETER) or {}).Machine
	if not proc then
		die("Could not detect processor architecture used in "..vars.LUA_INTERPRETER)
	end
	proc = pe.const.Machine[proc]  -- collect name from constant value
	if proc == "IMAGE_FILE_MACHINE_I386" then
		proc = "x86"
	else
		proc = "x86_64"
	end
	return proc
end

local function look_for_lua_install ()
	print("Looking for Lua interpreter")
	local directories
	if vars.LUA_PREFIX then
		directories = { vars.LUA_PREFIX }
	else
		-- no prefix given, so use path
		directories = (os.getenv("PATH",";") or "")
		local i = 1
        while i ~= 0 do directories, i = directories:gsub(";;",";") end  --remove all doubles
		directories = split_string(directories,";")
		-- if a path element ends with "\bin\" then remove it, as the searcher will check there anyway
		for i, val in ipairs(directories) do
			-- remove trailing backslash
			while val:sub(-1,-1) == "\\" and val:sub(-2,-1) ~= ":\\" do 
				val = val:sub(1,-2)
			end
			-- remove trailing 'bin'
			if val:upper():sub(-4,-1) == "\\BIN" or val:upper():sub(-4,-1) == ":BIN" then
				val = val:sub(1,-5)
			end
			directories[i] = val
		end
		-- finaly add some other default paths
		table.insert(directories, [[c:\lua5.1.2]])
		table.insert(directories, [[c:\lua]])
		table.insert(directories, [[c:\kepler\1.1]])
	end
	if vars.LUA_BINDIR and vars.LUA_LIBDIR and vars.LUA_INCDIR then
		if look_for_interpreter(vars.LUA_BINDIR) and 
			look_for_link_libraries(vars.LUA_LIBDIR) and
			look_for_headers(vars.LUA_INCDIR)
		then
			if get_runtime() then
				print("Runtime check completed, now testing interpreter...")
				if exec(S[["$LUA_BINDIR\$LUA_INTERPRETER" -v 2>NUL]]) then
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
							if exec(S[["$LUA_BINDIR\$LUA_INTERPRETER" -v 2>NUL]]) then
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


-- ***********************************************************
-- Installer script start
-- ***********************************************************

-- Poor man's command-line parsing
local config = {}
local with_arg = { -- options followed by an argument, others are flags
	["/P"] = true,
	["/CONFIG"] = true,
	["/TREE"] = true,
	["/SCRIPTS"] = true,
	["/LUAMOD"] = true,
	["/CMOD"] = true,
	["/LV"] = true,
	["/LUA"] = true,
	["/INC"] = true,
	["/BIN"] = true,
	["/LIB"] = true,
}
-- reconstruct argument values with spaces and double quotes
-- this will be damaged by the batch construction at the start of this file
local oarg = arg  -- retain old table
if #arg > 0 then
	farg = table.concat(arg, " ") .. " "
	arg = {}
	farg = farg:gsub('%"', "")
	local i = 0
	while #farg>0 do
		i = i + 1
		if (farg:sub(1,1) ~= "/") and ((arg[i-1] or ""):sub(1,1) ~= "/") then
			i = i - 1       -- continued previous arg
			if i == 0 then i = 1 end
		end
		if arg[i] then
			arg[i] = arg[i] .. " "
		else
			arg[i] = ""
		end
		local v,r = farg:match("^(.-)%s(.*)$")
		arg[i], farg = arg[i]..v, r
		while farg:sub(1,1) == " " do farg = farg:sub(2,-1) end	-- remove prefix spaces
	end
end
for k,v in pairs(oarg) do if k < 1 then arg[k] = v end end -- copy 0 and negative indexes
oarg = nil

-- build config option table with name and value elements
local i = 1
while i <= #arg do
	local opt = arg[i]
	if with_arg[opt:upper()] then
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

print([[

========================
== Checking system... ==
========================

]])

check_flags()

if not permission() then
	if not NOADMIN then
		-- must elevate the process with admin priviledges
        if not exec("PowerShell /? >NUL 2>&1") then
          -- powershell is not available, so error out
          die("No administrative priviledges detected and cannot auto-elevate. Please run with admin priviledges or use the /NOADMIN switch")
        end
		print("Need admin priviledges, now elevating a new process to continue installing...")
		local runner = os.getenv("TEMP").."\\".."LuaRocks_Installer.bat"
		local f = io.open(runner, "w")
		f:write("@echo off\n")
		f:write("CHDIR /D "..arg[0]:match("(.+)%\\.-$").."\n")  -- return to current dir, elevation changes current path
		f:write('"'..arg[-1]..'" "'..table.concat(arg, '" "', 0)..'"\n')
		f:write("ECHO Press any key to close this window...\n")
		f:write("PAUSE > NUL\n")
		f:write('DEL "'..runner..'"')  -- temp batch file deletes itself
		f:close()
		-- run the created temp batch file in elevated mode
		exec("PowerShell -Command (New-Object -com 'Shell.Application').ShellExecute('"..runner.."', '', '', 'runas')\n")
		print("Now exiting unpriviledged installer")
       	os.exit()  -- exit here, the newly created elevated process will do the installing
	else
		print("Attempting to install without admin priviledges...")
	end
else
	print("Admin priviledges available for installing")
end

vars.PREFIX = vars.PREFIX or os.getenv("PROGRAMFILES")..[[\LuaRocks]]
vars.FULL_PREFIX = S"$PREFIX\\$VERSION"
vars.BINDIR = vars.FULL_PREFIX
vars.LIBDIR = vars.FULL_PREFIX
vars.LUADIR = S"$FULL_PREFIX\\lua"
vars.INCDIR = S"$FULL_PREFIX\\include"
vars.LUA_SHORTV = vars.LUA_VERSION:gsub("%.", "")

if INSTALL_LUA then
	if vars.LUA_VERSION ~= "5.1" then
		die("Cannot install own copy of Lua because only 5.1 is bundled")
	end
	vars.LUA_INTERPRETER = "lua5.1"
	vars.LUA_BINDIR = vars.BINDIR
	vars.LUA_LIBDIR = vars.LIBDIR
	vars.LUA_INCDIR = vars.INCDIR
	vars.LUA_LIBNAME = "lua5.1.lib"
	vars.LUA_RUNTIME = "MSVCR80"
	vars.UNAME_M = "x86"
else
	if not look_for_lua_install() then
		die("Could not find Lua. See /? for options for specifying the location of Lua, or installing a bundled copy of Lua 5.1.")
	end
    vars.UNAME_M = get_architecture()  -- can only do when installation was found
end

local datapath
if vars.UNAME_M == "x86" then
	datapath = os.getenv("PROGRAMFILES") .. [[\LuaRocks]]
else
	-- our target interpreter is 64bit, so the tree (with binaries) should go into 64bit program files
	datapath = os.getenv("ProgramW6432") .. [[\LuaRocks]]
end
vars.SYSCONFDIR = vars.SYSCONFDIR or vars.PREFIX
vars.TREE_ROOT = vars.TREE_ROOT or datapath..[[\systree]]
if SELFCONTAINED then
	vars.SYSCONFDIR = vars.PREFIX
	vars.TREE_ROOT = vars.PREFIX..[[\systree]]
	REGISTRY = false
end

print(S[[

==========================
== System check results ==
==========================

Will configure LuaRocks with the following paths:
LuaRocks        : $FULL_PREFIX
Config file     : $SYSCONFDIR\config.lua
Rocktree        : $TREE_ROOT

Lua interpreter : $LUA_BINDIR\$LUA_INTERPRETER
    binaries    : $LUA_BINDIR
    libraries   : $LUA_LIBDIR
    includes    : $LUA_INCDIR
    architecture: $UNAME_M
    binary link : $LUA_LIBNAME with runtime $LUA_RUNTIME.dll

]])

if PROMPT then
	print("Press <ENTER> to start installing, or press <CTRL>+<C> to abort. Use install /? for installation options.")
	io.read()
end

print([[

============================
== Installing LuaRocks... ==
============================

]])

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
	exec(S[[COPY win32\lua5.1\bin\*.* "$LUA_BINDIR" >NUL]])
	exec(S[[COPY win32\lua5.1\include\*.* "$LUA_INCDIR" >NUL]])
	print(S"Installed the LuaRocks bundled Lua interpreter in $LUA_BINDIR")
end

-- Copy the LuaRocks binaries
if not exists(S[[$BINDIR\tools]]) then
	if not mkdir(S[[$BINDIR\tools]]) then
		die()
	end
end
if not exec(S[[COPY win32\tools\*.* "$BINDIR\tools" >NUL]]) then
	die()
end
-- Copy LR bin helper files
if not exec(S[[COPY win32\*.* "$BINDIR" >NUL]]) then
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
SET "LUA_PATH=$LUADIR\?.lua;$LUADIR\?\init.lua;%LUA_PATH%"
IF NOT "%LUA_PATH_5_2%"=="" (
   SET "LUA_PATH_5_2=$LUADIR\?.lua;$LUADIR\?\init.lua;%LUA_PATH_5_2%"
)
IF NOT "%LUA_PATH_5_3%"=="" (
   SET "LUA_PATH_5_3=$LUADIR\?.lua;$LUADIR\?\init.lua;%LUA_PATH_5_3%"
)
SET "PATH=$BINDIR;%PATH%"
"$LUA_BINDIR\$LUA_INTERPRETER" "$BINDIR\]]..c..[[.lua" %*
SET EXITCODE=%ERRORLEVEL%
IF NOT "%EXITCODE%"=="2" GOTO EXITLR

REM Permission denied error, try and auto elevate...
REM already an admin? (checking to prevent loops)
NET SESSION >NUL 2>&1
IF "%ERRORLEVEL%"=="0" GOTO EXITLR

REM Do we have PowerShell available?
PowerShell /? >NUL 2>&1
IF NOT "%ERRORLEVEL%"=="0" GOTO EXITLR

:GETTEMPNAME
SET TMPFILE=%TEMP%\LuaRocks-Elevator-%RANDOM%.bat
IF EXIST "%TMPFILE%" GOTO :GETTEMPNAME 

ECHO @ECHO OFF                                  >  "%TMPFILE%"
ECHO CHDIR /D %CD%                              >> "%TMPFILE%"
ECHO ECHO %0 %*                                 >> "%TMPFILE%"
ECHO ECHO.                                      >> "%TMPFILE%"
ECHO CALL %0 %*                                 >> "%TMPFILE%"
ECHO ECHO.                                      >> "%TMPFILE%"
ECHO ECHO Press any key to close this window... >> "%TMPFILE%"
ECHO PAUSE ^> NUL                               >> "%TMPFILE%"
ECHO DEL "%TMPFILE%"                            >> "%TMPFILE%"

ECHO Now retrying as a priviledged user...
PowerShell -Command (New-Object -com 'Shell.Application').ShellExecute('%TMPFILE%', '', '', 'runas')

:EXITLR
exit /b %EXITCODE% 
]])
	f:close()
	print(S"Created LuaRocks command: $BINDIR\\"..c..".bat")
end

-- part below was commented out as its purpose was unclear
-- see https://github.com/keplerproject/luarocks/pull/197#issuecomment-30176548

-- configure 'scripts' directory
-- if vars.TREE_BIN then
-- 	mkdir(vars.TREE_BIN)
-- 	if not USE_MINGW then
-- 		-- definitly not for MinGW because of conflicting runtimes
-- 		-- but is it ok to do it for others???
-- 		exec(S[[COPY lua5.1\bin\*.dll "$TREE_BIN" >NUL]])
-- 	end
-- else
-- 	if not USE_MINGW then
-- 	mkdir(S[[$TREE_ROOT\bin]])
-- 		-- definitly not for MinGW because of conflicting runtimes
-- 		-- but is it ok to do it for others???
-- 		exec(S[[COPY lua5.1\bin\*.dll "$TREE_ROOT"\bin >NUL]])
-- 	end
-- end

-- ***********************************************************
-- Configure LuaRocks
-- ***********************************************************

print()
print("Configuring LuaRocks...")

-- Create a site-config file
if exists(S[[$LUADIR\luarocks\site_config.lua]]) then
	exec(S[[RENAME "$LUADIR\luarocks\site_config.lua" site_config.lua.bak]])
end
local f = io.open(vars.LUADIR.."\\luarocks\\site_config.lua", "w")
f:write(S[=[
local site_config = {}
site_config.LUA_INCDIR=[[$LUA_INCDIR]]
site_config.LUA_LIBDIR=[[$LUA_LIBDIR]]
site_config.LUA_BINDIR=[[$LUA_BINDIR]]
site_config.LUA_INTERPRETER=[[$LUA_INTERPRETER]]
]=])
if USE_MINGW then
	f:write("site_config.LUAROCKS_UNAME_S=[[MINGW]]\n")
else
	f:write("site_config.LUAROCKS_UNAME_S=[[WindowsNT]]\n")
end
f:write(S[=[
site_config.LUAROCKS_UNAME_M=[[$UNAME_M]]
site_config.LUAROCKS_SYSCONFIG=[[$SYSCONFDIR\config.lua]]
site_config.LUAROCKS_ROCKS_TREE=[[$TREE_ROOT]]
site_config.LUAROCKS_PREFIX=[[$PREFIX]]
site_config.LUAROCKS_DOWNLOADER=[[wget]]
site_config.LUAROCKS_MD5CHECKER=[[md5sum]]
]=])
if FORCE_CONFIG then
	f:write("site_config.LUAROCKS_FORCE_CONFIG=true\n")
end
if exists(vars.LUADIR.."\\luarocks\\site_config.lua.bak") then
	for line in io.lines(vars.LUADIR.."\\luarocks\\site_config.lua.bak", "r") do
		f:write(line)
		f:write("\n")
	end
	exec(S[[DEL /F /Q "$LUADIR\luarocks\site_config.lua.bak"]])
end
f:write("return site_config\n")
f:close()
print(S[[Created LuaRocks site-config file: $LUADIR\luarocks\site_config.lua]])

-- create config file
vars.CONFIG_FILE = vars.SYSCONFDIR.."\\config.lua"
if not exists(vars.SYSCONFDIR) then
	mkdir(vars.SYSCONFDIR)
end
if exists(vars.CONFIG_FILE) then
	local nname = backup(vars.CONFIG_FILE, "config.bak")
	print("***************")
	print(S"*** WARNING *** LuaRocks config file already exists: '$CONFIG_FILE'. The old file has been renamed to '"..nname.."'")
	print("***************")
end
local f = io.open(vars.CONFIG_FILE, "w")
f:write([=[
rocks_trees = {
]=])
if FORCE_CONFIG then
	f:write("    home..[[/luarocks]],\n")
end
f:write(S"    { name = [[user]],\n")
f:write(S"         root    = home..[[/luarocks]],\n")
f:write(S"    },\n")
f:write(S"    { name = [[system]],\n")
f:write(S"         root    = [[$TREE_ROOT]],\n")
if vars.TREE_BIN then
  f:write(S"         bin_dir = [[$TREE_BIN]],\n")
end
if vars.TREE_CMODULE then
  f:write(S"         lib_dir = [[$TREE_CMODULE]],\n")
end
if vars.TREE_LMODULE then
  f:write(S"         lua_dir = [[$TREE_LMODULE]],\n")
end
f:write(S"    },\n")
f:write("}\n")
f:write("variables = {\n")
if USE_MINGW and vars.LUA_RUNTIME == "MSVCRT" then
	f:write("    MSVCRT = 'm',   -- make MinGW use MSVCRT.DLL as runtime\n")
else
	f:write("    MSVCRT = '"..vars.LUA_RUNTIME.."',\n")
end
f:write(S"    LUALIB = '$LUA_LIBNAME'\n")
f:write("}\n")
f:write("verbose = false   -- set to 'true' to enable verbose output\n")
f:close()

print(S"Created LuaRocks config file: $CONFIG_FILE")


print()
print("Creating rocktrees...")
if not exists(vars.TREE_ROOT) then
	mkdir(vars.TREE_ROOT)
	print(S[[Created system rocktree    : "$TREE_ROOT"]])
else
	print(S[[System rocktree exists     : "$TREE_ROOT"]])
end

vars.APPDATA = os.getenv("APPDATA")
vars.LOCAL_TREE = vars.APPDATA..[[\LuaRocks]]
if not exists(vars.LOCAL_TREE) then
	mkdir(vars.LOCAL_TREE)
	print(S[[Created local user rocktree: "$LOCAL_TREE"]])
else
	print(S[[Local user rocktree exists : "$LOCAL_TREE"]])
end

-- Load registry information
if REGISTRY then
	-- expand template with correct path information
	print()
	print([[Loading registry information for ".rockspec" files]])
	exec( S[[win32\lua5.1\bin\lua5.1.exe "$FULL_PREFIX\LuaRocks.reg.lua" "$FULL_PREFIX\LuaRocks.reg.template"]] )
	exec( S[[regedit /S "$FULL_PREFIX\\LuaRocks.reg"]] )
end

-- ***********************************************************
-- Cleanup
-- ***********************************************************
-- remove regsitry related files, no longer needed
exec( S[[del "$FULL_PREFIX\LuaRocks.reg.*" >NUL]] )
-- remove pe-parser module
exec( S[[del "$FULL_PREFIX\pe-parser.lua" >NUL]] )

-- ***********************************************************
-- Exit handlers 
-- ***********************************************************
vars.TREE_BIN     = vars.TREE_BIN     or vars.TREE_ROOT..[[\bin]]
vars.TREE_LMODULE = vars.TREE_LMODULE or vars.TREE_ROOT..[[\share\lua\]]..vars.LUA_VERSION
vars.TREE_CMODULE = vars.TREE_CMODULE or vars.TREE_ROOT..[[\lib\lua\]]..vars.LUA_VERSION
print(S[[

============================
== LuaRocks is installed! ==
============================


You may want to add the following elements to your paths;
Lua interpreter;
  PATH     :   $LUA_BINDIR
  PATHEXT  :   .LUA
LuaRocks;
  PATH     :   $FULL_PREFIX
  LUA_PATH :   $FULL_PREFIX\lua\?.lua;$FULL_PREFIX\lua\?\init.lua
Local user rocktree (Note: %APPDATA% is user dependent);
  PATH     :   %APPDATA%\LuaRocks\bin
  LUA_PATH :   %APPDATA%\LuaRocks\share\lua\$LUA_VERSION\?.lua;%APPDATA%\LuaRocks\share\lua\$LUA_VERSION\?\init.lua
  LUA_CPATH:   %APPDATA%\LuaRocks\lib\lua\$LUA_VERSION\?.dll
System rocktree
  PATH     :   $TREE_BIN
  LUA_PATH :   $TREE_LMODULE\?.lua;$TREE_LMODULE\?\init.lua
  LUA_CPATH:   $TREE_CMODULE\?.dll

Note that the %APPDATA% element in the paths above is user specific and it MUST be replaced by its actual value.
For the current user that value is: $APPDATA.

]])
os.exit(0)
