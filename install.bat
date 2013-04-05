@ECHO OFF

REM Boy, it feels like 1994 all over again.

SETLOCAL

SET PREFIX=C:\LuaRocks
SET VERSION=2.0
SET SYSCONFDIR=C:\LuaRocks
SET ROCKS_TREE=C:\LuaRocks
SET SCRIPTS_DIR=
SET FORCE=OFF
SET INSTALL_LUA=OFF
SET LUA_INTERPRETER=
SET LUA_PREFIX=
SET LUA_BINDIR=
SET LUA_INCDIR=
SET LUA_LIBDIR=
SET FORCE_CONFIG=
SET MKDIR=.\bin\mkdir -p

REM ***********************************************************
REM Option parser
REM ***********************************************************

:PARSE_LOOP
IF [%1]==[] GOTO DONE_PARSING
IF [%1]==[/?] (
   ECHO Installs LuaRocks.
   ECHO.
   ECHO /P [dir]       Where to install.
   ECHO                Default is %PREFIX% (version; %VERSION%, will be
   ECHO                appended to this path^)
   ECHO /CONFIG [dir]  Location where the config file should be installed.
   ECHO                Default is same place of installation
   ECHO /TREE [dir]    Root of the local tree of installed rocks.
   ECHO                Default is same place of installation
   ECHO /SCRIPTS [dir] Where to install scripts installed by rocks.
   ECHO                Default is TREE/bin.
   ECHO.
   ECHO /L             Install LuaRocks' own copy of Lua even if detected.
   ECHO                (/LUA, /INC, /LIB, /BIN will be ignored when used 
   ECHO                with /L^)
   ECHO /LUA [dir]     Location where Lua is installed - e.g. c:\lua\5.1\
   ECHO                This is the base directory, the installer will look
   ECHO                for subdirectories bin, lib, include. Alternatively
   ECHO                these can be specified explicitly using the /INC,
   ECHO                /LIB, and /BIN options.
   ECHO /INC [dir]     Location of Lua includes - e.g. c:\lua\5.1\include
   ECHO                If provided overrides sub directory found using /LUA.
   ECHO /LIB [dir]     Location of Lua libraries -e.g. c:\lua\5.1\lib
   ECHO                If provided overrides sub directory found using /LUA.
   ECHO /BIN [dir]     Location of Lua executables - e.g. c:\lua\5.1\bin
   ECHO                If provided overrides sub directory found using /LUA.
   ECHO.
   ECHO /MW            Use mingw as build system instead of MSVC
   ECHO.
   ECHO /FORCECONFIG   Use a single config location. Do not use the
   ECHO                LUAROCKS_CONFIG variable or the user's home directory.
   ECHO                Useful to avoid conflicts when LuaRocks
   ECHO                is embedded within an application.
   ECHO.
   ECHO /F             Remove installation directory if it already exists.
   ECHO.
   GOTO QUIT
)
IF /I [%1]==[/P] (
   SET PREFIX=%2
   SET SYSCONFDIR=%2
   SET ROCKS_TREE=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/CONFIG] (
   SET SYSCONFDIR=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/TREE] (
   SET ROCKS_TREE=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/SCRIPTS] (
   SET SCRIPTS_DIR=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/L] (
   SET INSTALL_LUA=ON
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/MW] (
   SET USE_MINGW=ON
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/LUA] (
   SET LUA_PREFIX=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/LIB] (
   SET LUA_LIBDIR=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/INC] (
   SET LUA_INCDIR=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/BIN] (
   SET LUA_BINDIR=%2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/FORCECONFIG] (
   SET FORCE_CONFIG=ON
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/F] (
   SET FORCE=ON
   SHIFT /1
   GOTO PARSE_LOOP
)
ECHO Unrecognized option: %1
GOTO ERROR
:DONE_PARSING

SET FULL_PREFIX=%PREFIX%\%VERSION%

SET BINDIR=%FULL_PREFIX%
SET LIBDIR=%FULL_PREFIX%
SET LUADIR=%FULL_PREFIX%\lua
SET INCDIR=%FULL_PREFIX%\include

REM ***********************************************************
REM Detect Lua
REM ***********************************************************

IF [%INSTALL_LUA%]==[ON] GOTO USE_OWN_LUA

FOR %%L IN (%LUA_PREFIX% c:\lua\5.1.2 c:\lua c:\kepler\1.1) DO (
   SET CURR=%%L
   IF EXIST "%%L" (
      IF NOT [%LUA_BINDIR%]==[] (
         IF EXIST %LUA_BINDIR%\lua5.1.exe (
            SET LUA_INTERPRETER=lua5.1.exe
            GOTO INTERPRETER_IS_SET
         )
         IF EXIST %LUA_BINDIR%\lua.exe (
            SET LUA_INTERPRETER=lua.exe
            GOTO INTERPRETER_IS_SET
         )		 
         IF EXIST %LUA_BINDIR%\luajit.exe (
            SET LUA_INTERPRETER=luajit.exe
            GOTO INTERPRETER_IS_SET
         )		 
         ECHO Lua executable lua.exe, luajit.exe or lua5.1.exe not found in %LUA_BINDIR%
         GOTO ERROR
      )
      SET CURR=%%L
      FOR %%E IN (\ \bin\) DO (
         IF EXIST "%%L%%E\lua5.1.exe" (
            SET LUA_INTERPRETER=lua5.1.exe
            SET LUA_BINDIR=%%L%%E
            GOTO INTERPRETER_IS_SET
         )
         IF EXIST "%%L%%E\lua.exe" (
            SET LUA_INTERPRETER=lua.exe
            SET LUA_BINDIR=%%L%%E
            GOTO INTERPRETER_IS_SET
         )
         IF EXIST "%%L%%E\luajit.exe" (
            SET LUA_INTERPRETER=luajit.exe
            SET LUA_BINDIR=%%L%%E
            GOTO INTERPRETER_IS_SET
         )
      )
      GOTO TRY_NEXT_LUA_DIR
      :INTERPRETER_IS_SET
      IF NOT "%LUA_LIBDIR%"=="" (
         IF EXIST %LUA_LIBDIR%\lua5.1.lib GOTO LIBDIR_IS_SET
         ECHO lua5.1.lib not found in %LUA_LIBDIR%
         GOTO ERROR
      )
      FOR %%E IN (\ \lib\ \bin\) DO (
         IF EXIST "%CURR%%%E\lua5.1.lib" (
            SET LUA_LIBDIR=%CURR%%%E
            GOTO LIBDIR_IS_SET
         )
      )
      GOTO TRY_NEXT_LUA_DIR
      :LIBDIR_IS_SET
      IF NOT [%LUA_INCDIR%]==[] (
         IF EXIST %LUA_INCDIR%\lua.h GOTO INCDIR_IS_SET
         ECHO lua.h not found in %LUA_INCDIR%
         GOTO ERROR
      )
      FOR %%E IN (\ \include\) DO (
         IF EXIST "%CURR%%%E\lua.h" (
            SET LUA_INCDIR=%CURR%%%E
            GOTO INCDIR_IS_SET
         )
      )
      GOTO TRY_NEXT_LUA_DIR
      :INCDIR_IS_SET
	%LUA_BINDIR%\%LUA_INTERPRETER% -v 2>NUL
      IF NOT ERRORLEVEL 1 (
         GOTO LUA_IS_SET
      )
   )
:TRY_NEXT_LUA_DIR
   REM wtf
)
ECHO Could not find Lua. Will install its own copy.
ECHO See /? for options for specifying the location of Lua.
:USE_OWN_LUA
SET INSTALL_LUA=ON
SET LUA_INTERPRETER=lua5.1
SET LUA_BINDIR=%BINDIR%
SET LUA_LIBDIR=%LIBDIR%
SET LUA_INCDIR=%INCDIR%
:LUA_IS_SET
ECHO.
ECHO Will configure LuaRocks with the following paths:
ECHO Lua interpreter: %LUA_INTERPRETER%
ECHO Lua binaries:    %LUA_BINDIR%
ECHO Lua libraries:   %LUA_LIBDIR%
ECHO Lua includes:    %LUA_INCDIR%
ECHO.

REM ***********************************************************
REM Install LuaRocks files
REM ***********************************************************

IF [%FORCE%]==[ON] (
   ECHO Removing %FULL_PREFIX%...
   RD /S /Q "%FULL_PREFIX%"
)

IF NOT EXIST "%FULL_PREFIX%" GOTO NOT_EXIST_PREFIX
   ECHO %FULL_PREFIX% exists. Use /F to force removal and reinstallation.
   GOTO ERROR
:NOT_EXIST_PREFIX

ECHO Installing LuaRocks in %FULL_PREFIX%...
IF NOT EXIST "%BINDIR%" %MKDIR% "%BINDIR%"
IF ERRORLEVEL 1 GOTO ERROR
IF [%INSTALL_LUA%]==[ON] (
   REM Copy the included Lua interpreter binaries
   IF NOT EXIST "%LUA_BINDIR%" %MKDIR% "%LUA_BINDIR%"
   IF NOT EXIST "%LUA_INCDIR%" %MKDIR% "%LUA_INCDIR%"
   COPY lua5.1\bin\*.* "%LUA_BINDIR%" >NUL
   COPY lua5.1\include\*.* "%LUA_INCDIR%" >NUL
   ECHO Installed the LuaRocks bundled Lua interpreter in %LUA_BINDIR%
)
REM Copy the LuaRocks binaries
COPY bin\*.* "%BINDIR%" >NUL
IF ERRORLEVEL 1 GOTO ERROR
REM Copy the LuaRocks lua source files
IF NOT EXIST "%LUADIR%\luarocks" %MKDIR% "%LUADIR%\luarocks"
IF ERRORLEVEL 1 GOTO ERROR
XCOPY /S src\luarocks\*.* "%LUADIR%\luarocks" >NUL
IF ERRORLEVEL 1 GOTO ERROR
REM Create start scripts
COPY src\bin\*.* "%BINDIR%" >NUL
IF ERRORLEVEL 1 GOTO ERROR
FOR %%C IN (luarocks luarocks-admin) DO (
   REM rename unix-lua scripts to .lua files
   RENAME "%BINDIR%\%%C" %%C.lua
   IF ERRORLEVEL 1 GOTO ERROR
   REM create a bootstrap batch file for the lua file, to start them
   DEL /F /Q "%BINDIR%\%%C.bat" 2>NUL
   ECHO @ECHO OFF>> "%BINDIR%\%%C.bat"
   ECHO SETLOCAL>> "%BINDIR%\%%C.bat"
   ECHO SET LUA_PATH=%LUADIR%\?.lua;%LUADIR%\?\init.lua;%%LUA_PATH%%>> "%BINDIR%\%%C.bat"
   ECHO SET PATH=%BINDIR%\;%%PATH%%>> "%BINDIR%\%%C.bat"
   ECHO "%LUA_INTERPRETER%" "%BINDIR%\%%C.lua" %%*>> "%BINDIR%\%%C.bat"
   ECHO ENDLOCAL>> "%BINDIR%\%%C.bat"
   ECHO Created LuaRocks command: %BINDIR%\%%C.bat
)
REM configure 'scripts' directory
IF [%SCRIPTS_DIR%]==[] (
   %MKDIR% "%ROCKS_TREE%"\bin >NUL
   IF [%USE_MINGW%]==[] (
     REM definitly not for MinGW because of conflicting runtimes
     REM but is it ok to do it for others???
     COPY lua5.1\bin\*.dll "%ROCKS_TREE%"\bin >NUL
   )
) ELSE (
   %MKDIR% "%SCRIPTS_DIR%" >NUL
   IF [%USE_MINGW%]==[] (
     REM definitly not for MinGW because of conflicting runtimes
     REM but is it ok to do it for others???
     COPY lua5.1\bin\*.dll "%SCRIPTS_DIR%" >NUL
   )
)


ECHO.
ECHO Configuring LuaRocks...
REM Create a site-config file
IF EXIST "%LUADIR%\luarocks\site_config.lua" RENAME "%LUADIR%\luarocks\site_config.lua" site_config.lua.bak
ECHO module("luarocks.site_config")>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUA_INCDIR=[[%LUA_INCDIR%]]>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUA_LIBDIR=[[%LUA_LIBDIR%]]>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUA_BINDIR=[[%LUA_BINDIR%]]>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUA_INTERPRETER=[[%LUA_INTERPRETER%]]>> "%LUADIR%\luarocks\site_config.lua" 
IF [%USE_MINGW%]==[ON] (
ECHO LUAROCKS_UNAME_S=[[MINGW]]>> "%LUADIR%\luarocks\site_config.lua" 
) ELSE (
ECHO LUAROCKS_UNAME_S=[[WindowsNT]]>> "%LUADIR%\luarocks\site_config.lua" 
)
ECHO LUAROCKS_UNAME_M=[[x86]]>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUAROCKS_SYSCONFIG=[[%SYSCONFDIR%/config.lua]]>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUAROCKS_ROCKS_TREE=[[%ROCKS_TREE%]]>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUAROCKS_PREFIX=[[%PREFIX%]]>> "%LUADIR%\luarocks\site_config.lua" 
ECHO LUAROCKS_DOWNLOADER=[[wget]]>> "%LUADIR%\luarocks\site_config.lua"
ECHO LUAROCKS_MD5CHECKER=[[md5sum]]>> "%LUADIR%\luarocks\site_config.lua"
IF NOT [%FORCE_CONFIG%]==[] ECHO local LUAROCKS_FORCE_CONFIG=true>> "%LUADIR%\luarocks\site_config.lua"
IF EXIST "%LUADIR%\luarocks\site_config.lua.bak" TYPE "%LUADIR%\luarocks\site_config.lua.bak">> "%LUADIR%\luarocks\site_config.lua" 

IF EXIST "%LUADIR%\luarocks\site_config.lua.bak" DEL /F /Q "%LUADIR%\luarocks\site_config.lua.bak"
ECHO Created LuaRocks site-config file: %LUADIR%\luarocks\site_config.lua

REM create config file
SET CONFIG_FILE=%SYSCONFDIR%\config.lua

IF NOT EXIST "%SYSCONFDIR%" %MKDIR% "%SYSCONFDIR%"
IF NOT EXIST "%CONFIG_FILE%" (
   ECHO rocks_servers = {>> "%CONFIG_FILE%"
   ECHO    [[http://luarocks.org/repositories/rocks]]>> "%CONFIG_FILE%"
   ECHO }>> "%CONFIG_FILE%"
   ECHO rocks_trees = {>> "%CONFIG_FILE%"
   IF [%FORCE_CONFIG%]==[] ECHO    home..[[/luarocks]],>> "%CONFIG_FILE%"
   ECHO    [[%ROCKS_TREE%]]>> "%CONFIG_FILE%"
   ECHO }>> "%CONFIG_FILE%"
   IF NOT [%SCRIPTS_DIR%]==[] ECHO scripts_dir=[[%SCRIPTS_DIR%]]>> "%CONFIG_FILE%"
   ECHO Created LuaRocks config file: %CONFIG_FILE%
) ELSE (
   ECHO LuaRocks config file already exists: %CONFIG_FILE%
)

ECHO.
ECHO Creating rocktrees...
IF NOT EXIST "%ROCKS_TREE%" (
   %MKDIR% "%ROCKS_TREE%"
   ECHO Created rocktree: "%ROCKS_TREE%"
) ELSE (
   ECHO Rocktree exists: "%ROCKS_TREE%"
)
IF NOT EXIST "%APPDATA%/luarocks" (
   %MKDIR% "%APPDATA%/luarocks"
   ECHO Created rocktree: "%APPDATA%\luarocks"
) ELSE (
   ECHO Rocktree exists: "%APPDATA%\luarocks"
)

REM ***********************************************************
REM Exit handlers 
REM ***********************************************************

ECHO.
ECHO You may want to add the following elements to your paths;
ECHO PATH     :   %LUA_BINDIR%;%FULL_PREFIX%
ECHO LUA_PATH :   %ROCKS_TREE%\share\lua\5.1\?.lua;%ROCKS_TREE%\share\lua\5.1\?\init.lua
ECHO LUA_CPATH:   %LUA_LIBDIR%\lua\5.1\?.dll
ECHO.
ECHO LuaRocks is installed!
:QUIT
ENDLOCAL
EXIT /B 0

:ERROR
ECHO.
ECHO Failed installing LuaRocks.
ENDLOCAL
EXIT /B 1
