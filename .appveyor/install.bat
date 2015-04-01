@echo off

cd %APPVEYOR_BUILD_FOLDER%

:: =========================================================
:: Set some defaults. Infer some variables.
::
:: These are set globally
if "%LUA_VER%" NEQ "" (
	set LUA=lua
	set LUA_SHORTV=%LUA_VER:~0,3%
) else (
	set LUA=luajit
	set LJ_SHORTV=%LJ_VER:~0,3%
	set LUA_SHORTV=5.1
)

:: unless we specify a platform on appveyor.yaml, we won't get this variable
if not defined platform set platform=x86

:: defines LUA_DIR so Cmake can find this Lua install
if "%LUA%"=="luajit" (
	set LUA_DIR=c:\lua\%platform%\lj%LJ_SHORTV%
) else (
	set LUA_DIR=c:\lua\%platform%\%LUA_VER%
)

:: Now we declare a scope
Setlocal EnableDelayedExpansion EnableExtensions

if not defined LUA_URL set LUA_URL=http://www.lua.org/ftp
if not defined LUAJIT_GIT_REPO set LUAJIT_GIT_REPO=http://luajit.org/git/luajit-2.0.git
if not defined LUAJIT_URL set LUAJIT_URL=http://luajit.org/download

if not defined SEVENZIP set SEVENZIP=7z
::
:: =========================================================

:: first create some necessary directories:
mkdir downloads 2>NUL

:: Download and compile Lua (or LuaJIT)
if "%LUA%"=="luajit" (
	if not exist %LUA_DIR% (
		if "%LJ_SHORTV%"=="2.1" (
			:: Clone repository and checkout 2.1 branch
			set lj_source_folder=%APPVEYOR_BUILD_FOLDER%\downloads\luajit-%LJ_VER%
			if not exist !lj_source_folder! (
				echo Cloning git repo %LUAJIT_GIT_REPO% !lj_source_folder!
				git clone %LUAJIT_GIT_REPO% !lj_source_folder! || call :die "Failed to clone repository"
			)
			cd !lj_source_folder!\src
			git checkout v2.1 || call :die
		) else (
			set lj_source_folder=%APPVEYOR_BUILD_FOLDER%\downloads\luajit-%LJ_VER%
			if not exist !lj_source_folder! (
				echo Downloading... %LUAJIT_URL%/LuaJIT-%LJ_VER%.tar.gz
				curl --silent --fail --max-time 120 --connect-timeout 30 %LUAJIT_URL%/LuaJIT-%LJ_VER%.tar.gz | %SEVENZIP% x -si -so -tgzip | %SEVENZIP% x -si -ttar -aoa -odownloads
			)
			cd !lj_source_folder!\src
		)
		:: Compiles LuaJIT
		call msvcbuild.bat

		mkdir %LUA_DIR% 2> NUL
		for %%a in (bin include lib) do ( mkdir "%LUA_DIR%\%%a" )

		for %%a in (luajit.exe lua51.dll) do ( move "!lj_source_folder!\src\%%a" "%LUA_DIR%\bin" )

		move "!lj_source_folder!\src\lua51.lib" "%LUA_DIR%\lib"
		for %%a in (lauxlib.h lua.h lua.hpp luaconf.h lualib.h luajit.h) do (
			copy "!lj_source_folder!\src\%%a" "%LUA_DIR%\include"
		)

	) else (
		echo LuaJIT %LJ_VER% already installed at %LUA_DIR%
	)
) else (
	if not exist %LUA_DIR% (
		:: Download and compile Lua
		if not exist downloads\lua-%LUA_VER% (
			curl --silent --fail --max-time 120 --connect-timeout 30 %LUA_URL%/lua-%LUA_VER%.tar.gz | %SEVENZIP% x -si -so -tgzip | %SEVENZIP% x -si -ttar -aoa -odownloads
		)
		
		mkdir downloads\lua-%LUA_VER%\etc 2> NUL
		if not exist downloads\lua-%LUA_VER%\etc\winmake.bat (
			curl --silent --location --insecure --fail --max-time 120 --connect-timeout 30 https://github.com/Tieske/luawinmake/archive/master.tar.gz | %SEVENZIP% x -si -so -tgzip | %SEVENZIP% e -si -ttar -aoa -odownloads\lua-%LUA_VER%\etc luawinmake-master\etc\winmake.bat
		)

		cd downloads\lua-%LUA_VER%
		call etc\winmake
		call etc\winmake install %LUA_DIR%
	) else (
		echo Lua %LUA_VER% already installed at %LUA_DIR%
	)
)

if not exist %LUA_DIR%\bin\%LUA%.exe call :die "Missing Lua interpreter at %LUA_DIR%\bin\%LUA%.exe"

set PATH=%LUA_DIR%\bin;%PATH%
call %LUA% -v



:: Exports the following variables:
endlocal & set PATH=%PATH%

echo.
echo ======================================================
if "%LUA%"=="luajit" (
	echo Installation of LuaJIT %LJ_VER% done.
) else (
	echo Installation of Lua %LUA_VER% done.
)
echo Platform         - %platform%
echo LUA              - %LUA%
echo LUA_SHORTV       - %LUA_SHORTV%
echo LJ_SHORTV        - %LJ_SHORTV%
echo.
echo ======================================================
echo.

goto :eof


















:: This blank space is intentional. If you see errors like "The system cannot find the batch label specified 'foo'"
:: then try adding or removing blank lines lines above.
:: Yes, really.
:: http://stackoverflow.com/questions/232651/why-the-system-cannot-find-the-batch-label-specified-is-thrown-even-if-label-e

:: helper functions:

:: for bailing out when an error occurred
:die %1
echo %1
exit /B 1
goto :eof

