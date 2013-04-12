@ECHO OFF

REM Boy, it feels like 1994 all over again.

SETLOCAL ENABLEDELAYEDEXPANSION 

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
SET LUA_LIBNAME=
SET FORCE_CONFIG=
SET USE_MINGW=
SET MKDIR=.\bin\mkdir -p
SET LUA_VERSION=5.1
SET LUA_SHORTV=
SET LUA_LIB_NAMES=lua5.1.lib lua51.dll liblua.dll.a 
SET REGISTRY=OFF
SET P_SET=FALSE

REM ***********************************************************
REM Option parser
REM ***********************************************************
ECHO LuaRocks %VERSION%.x installer.
ECHO.

:PARSE_LOOP
IF [%1]==[] GOTO DONE_PARSING
IF [%1]==[/?] (
   ECHO Installs LuaRocks.
   ECHO.
   ECHO /P [dir]       ^(REQUIRED^) Where to install. 
   ECHO                Note that version; %VERSION%, will be
   ECHO                appended to this path.
   ECHO /CONFIG [dir]  Location where the config file should be installed.
   ECHO                Default is same place of installation
   ECHO /TREE [dir]    Root of the local tree of installed rocks.
   ECHO                Default is same place of installation
   ECHO /SCRIPTS [dir] Where to install scripts installed by rocks.
   ECHO                Default is TREE/bin.
   ECHO.
   ECHO /LV [version]  Lua version to use; either 5.1 or 5.2.
   ECHO                Default is 5.1
   ECHO /L             Install LuaRocks' own copy of Lua even if detected,
   ECHO                this will always be a 5.1 installation.
   ECHO                ^(/LUA, /INC, /LIB, /BIN cannot be used with /L^)
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
   ECHO /R             Load registry information to register '.rockspec'
   ECHO                extension with LuaRocks commands ^(right-click^).
   ECHO.
   GOTO QUIT
)
IF /I [%1]==[/P] (
   SET PREFIX=%~2
   SET SYSCONFDIR=%~2
   SET ROCKS_TREE=%~2
   SET P_SET=TRUE
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/CONFIG] (
   SET SYSCONFDIR=%~2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/TREE] (
   SET ROCKS_TREE=%~2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/SCRIPTS] (
   SET SCRIPTS_DIR=%~2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/LV] (
   SET LUA_VERSION=%~2
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
   SET LUA_PREFIX=%~2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/LIB] (
   SET LUA_LIBDIR=%~2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/INC] (
   SET LUA_INCDIR=%~2
   SHIFT /1
   SHIFT /1
   GOTO PARSE_LOOP
)
IF /I [%1]==[/BIN] (
   SET LUA_BINDIR=%~2
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
IF /I [%1]==[/R] (
   SET REGISTRY=ON
   SHIFT /1
   GOTO PARSE_LOOP
)
ECHO Unrecognized option: %1
GOTO ERROR
:DONE_PARSING

REM check for combination/required flags
IF NOT [%P_SET%]==[TRUE] (
   Echo Missing required parameter /P
   GOTO ERROR
)
IF [%INSTALL_LUA%]==[ON] (
   IF NOT [%LUA_INCDIR%%LUA_BINDIR%%LUA_LIBDIR%%LUA_PREFIX%]==[] (
      ECHO Cannot combine option /L with any of /LUA /BIN /LIB /INC
      GOTO ERROR
   )
   IF NOT [%LUA_VERSION%]==[5.1] (
      ECHO Bundled Lua version is 5.1, cannot install 5.2
      GOTO ERROR
   )
)
IF NOT [%LUA_VERSION%]==[5.1] (
   IF [%LUA_VERSION%]==[5.2] (
      SET LUA_LIB_NAMES=%LUA_LIB_NAMES:5.1=5.2%
      SET LUA_LIB_NAMES=%LUA_LIB_NAMES:51=52%
   ) ELSE (
      ECHO Bad argument: /LV must either be 5.1 or 5.2
      GOTO ERROR
   )
)

SET FULL_PREFIX=%PREFIX%\%VERSION%
SET BINDIR=%FULL_PREFIX%
SET LIBDIR=%FULL_PREFIX%
SET LUADIR=%FULL_PREFIX%\lua
SET INCDIR=%FULL_PREFIX%\include
SET LUA_SHORTV=%LUA_VERSION:.=%

REM ***********************************************************
REM Detect Lua
REM ***********************************************************

IF [%INSTALL_LUA%]==[ON] GOTO USE_OWN_LUA

ECHO Looking for Lua interpreter
FOR %%L IN (%LUA_PREFIX% c:\lua\5.1.2 c:\lua c:\kepler\1.1) DO (
   ECHO    checking %%L
   SET CURR=%%L
   IF EXIST "%%L" (
      IF NOT [%LUA_BINDIR%]==[] (
         IF EXIST %LUA_BINDIR%\lua%LUA_VERSION%.exe (
            SET LUA_INTERPRETER=lua%LUA_VERSION%.exe
            ECHO       Found .\!LUA_INTERPRETER!
            GOTO INTERPRETER_IS_SET
         )
         IF EXIST %LUA_BINDIR%\lua.exe (
            SET LUA_INTERPRETER=lua.exe
            ECHO       Found .\!LUA_INTERPRETER!
            GOTO INTERPRETER_IS_SET
         )		 
         IF EXIST %LUA_BINDIR%\luajit.exe (
            SET LUA_INTERPRETER=luajit.exe
            ECHO       Found .\!LUA_INTERPRETER!
            GOTO INTERPRETER_IS_SET
         )		 
         ECHO Lua executable lua.exe, luajit.exe or lua%LUA_VERSION%.exe not found in %LUA_BINDIR%
         GOTO ERROR
      )
      SET CURR=%%L
      FOR %%E IN (\ \bin\) DO (
         IF EXIST "%%L%%E\lua%LUA_VERSION%.exe" (
            SET LUA_INTERPRETER=lua%LUA_VERSION%.exe
            SET LUA_BINDIR=%%L%%E
            ECHO       Found .\%%E\!LUA_INTERPRETER!
            GOTO INTERPRETER_IS_SET
         )
         IF EXIST "%%L%%E\lua.exe" (
            SET LUA_INTERPRETER=lua.exe
            SET LUA_BINDIR=%%L%%E
            ECHO       Found .\%%E\!LUA_INTERPRETER!
            GOTO INTERPRETER_IS_SET
         )
         IF EXIST "%%L%%E\luajit.exe" (
            SET LUA_INTERPRETER=luajit.exe
            SET LUA_BINDIR=%%L%%E
            ECHO       Found .\%%E\!LUA_INTERPRETER!
            GOTO INTERPRETER_IS_SET
         )
      )
      ECHO      No Lua interpreter found
      GOTO TRY_NEXT_LUA_DIR
      :INTERPRETER_IS_SET
      ECHO Interpreter found, now looking for link libraries...
      IF NOT [%LUA_LIBDIR%]==[] (
         FOR %%T IN (%LUA_LIB_NAMES%) DO (
            ECHO    checking for %LUA_LIBDIR%\%%T
            IF EXIST "%LUA_LIBDIR%\%%T" (
               SET LUA_LIBNAME=%%T
               ECHO       Found %%T
               GOTO LIBDIR_IS_SET
            )
         )
         ECHO link library ^(one of; %LUA_LIB_NAMES%^) not found in %LUA_LIBDIR%
         GOTO ERROR
      )
      FOR %%E IN (\ \lib\ \bin\) DO (
         FOR %%S IN (%LUA_LIB_NAMES%) DO (
            ECHO    checking for %CURR%%%E\%%S
            IF EXIST "%CURR%%%E\%%S" (
               SET LUA_LIBDIR=%CURR%%%E
               SET LUA_LIBNAME=%%S
               ECHO       Found %%S
               GOTO LIBDIR_IS_SET
            )
         )
      )
      GOTO TRY_NEXT_LUA_DIR
      :LIBDIR_IS_SET
      ECHO Link library found, now looking for headers...
      IF NOT [%LUA_INCDIR%]==[] (
         ECHO    checking for %LUA_INCDIR%\lua.h
         IF EXIST %LUA_INCDIR%\lua.h (
            ECHO       Found lua.h
            GOTO INCDIR_IS_SET
         )
         ECHO lua.h not found in %LUA_INCDIR%
         GOTO ERROR
      )
      FOR %%E IN (\ \include\) DO (
         ECHO    checking for %CURR%%%E\lua.h
         IF EXIST "%CURR%%%E\lua.h" (
            SET LUA_INCDIR=%CURR%%%E
            ECHO       Found lua.h
            GOTO INCDIR_IS_SET
         )
      )
      GOTO TRY_NEXT_LUA_DIR
      :INCDIR_IS_SET
      ECHO Headers found, now testing interpreter...
      %LUA_BINDIR%\%LUA_INTERPRETER% -v 2>NUL
      IF NOT ERRORLEVEL 1 (
         ECHO   Ok
         GOTO LUA_IS_SET
      )
      ECHO   Interpreter returned an error, not ok
   )
:TRY_NEXT_LUA_DIR
   REM wtf
)
ECHO Could not find Lua. Will install its own copy.
ECHO See /? for options for specifying the location of Lua.
:USE_OWN_LUA
IF NOT [%LUA_VERSION%]==[5.1] (
   ECHO Cannot install own copy because no 5.2 version is bundled
   GOTO ERROR
)
SET INSTALL_LUA=ON
SET LUA_INTERPRETER=lua5.1
SET LUA_BINDIR=%BINDIR%
SET LUA_LIBDIR=%LIBDIR%
SET LUA_INCDIR=%INCDIR%
SET LUA_LIBNAME=lua5.1.lib
:LUA_IS_SET
ECHO.
ECHO Will configure LuaRocks with the following paths:
ECHO LuaRocks       : %FULL_PREFIX%
ECHO Lua interpreter: %LUA_BINDIR%\%LUA_INTERPRETER%
ECHO Lua binaries   : %LUA_BINDIR%
ECHO Lua libraries  : %LUA_LIBDIR%
ECHO Lua includes   : %LUA_INCDIR%
ECHO Binaries will be linked against: %LUA_LIBNAME%
ECHO.

REM ***********************************************************
REM Install LuaRocks files
REM ***********************************************************

IF [%FORCE%]==[ON] (
   ECHO Removing %FULL_PREFIX%...
   RD /S /Q "%FULL_PREFIX%"
   ECHO.
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
   ECHO variables = {>> "%CONFIG_FILE%"
   IF [%USE_MINGW%]==[ON] (
   ECHO    MSVCRT = 'm',>> "%CONFIG_FILE%"
   ) ELSE (
   ECHO    MSVCRT = 'msvcr80',>> "%CONFIG_FILE%"
   )
   ECHO    LUALIB = '%LUA_LIBNAME%'>> "%CONFIG_FILE%"
   ECHO }>> "%CONFIG_FILE%"
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

REM Load registry information
IF [%REGISTRY%]==[ON] (
   REM expand template with correct path information
   ECHO.
   ECHO Loading registry information for ".rockspec" files
   lua5.1\bin\lua5.1.exe "%FULL_PREFIX%\create_reg_file.lua" "%FULL_PREFIX%\LuaRocks.reg.template"
   %FULL_PREFIX%\LuaRocks.reg
)

REM ***********************************************************
REM Exit handlers 
REM ***********************************************************

ECHO.
ECHO    *** LuaRocks is installed! ***
ECHO.
ECHO You may want to add the following elements to your paths;
ECHO PATH     :   %LUA_BINDIR%;%FULL_PREFIX%
ECHO LUA_PATH :   %ROCKS_TREE%\share\lua\%LUA_VERSION%\?.lua;%ROCKS_TREE%\share\lua\%LUA_VERSION%\?\init.lua
ECHO LUA_CPATH:   %LUA_LIBDIR%\lua\%LUA_VERSION%\?.dll
ECHO.
:QUIT
ENDLOCAL
EXIT /B 0

:ERROR
ECHO.
ECHO Failed installing LuaRocks. Run with /? for help.
ENDLOCAL
EXIT /B 1
