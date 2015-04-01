@echo off
Setlocal EnableDelayedExpansion EnableExtensions

cd %APPVEYOR_BUILD_FOLDER%

:: =========================================================
:: Make sure some environment variables are set
if not defined LUA_VER call :die LUA_VER is not defined
if not defined LUA call :die LUA is not defined
if not defined LUA_SHORTV call :die LUA_SHORTV is not defined
if not defined LUA_DIR call :die LUA_DIR is not defined

:: =========================================================
:: Set some defaults. Infer some variables.
::
if not defined LUAROCKS_VER set LUAROCKS_VER=2.2.1

set LUAROCKS_SHORTV=%LUAROCKS_VER:~0,3%

if not defined LR_EXTERNAL set LR_EXTERNAL=c:\external
if not defined LUAROCKS_INSTALL set LUAROCKS_INSTALL=%LUA_DIR%\LuaRocks
if not defined LR_ROOT set LR_ROOT=%LUAROCKS_INSTALL%\%LUAROCKS_SHORTV%
if not defined LR_SYSTREE set LR_SYSTREE=%LUAROCKS_INSTALL%\systree

::
:: =========================================================


if not exist %LUA_DIR%\bin\%LUA%.exe call :die "Missing Lua interpreter at %LUA_DIR%\bin\%LUA%.exe"



:: =========================================================
:: LuaRocks
:: =========================================================

cd %APPVEYOR_BUILD_FOLDER%
call install.bat /LUA %LUA_DIR% /Q /LV %LUA_SHORTV% /P "%LUAROCKS_INSTALL%" /TREE "%LR_SYSTREE%"

if not exist "%LR_ROOT%" call :die "LuaRocks not found at %LR_ROOT%"

set PATH=%LR_ROOT%;%LR_SYSTREE%\bin;%PATH%

:: Lua will use just the system rocks
set LUA_PATH=%LR_ROOT%\lua\?.lua;%LR_ROOT%\lua\?\init.lua
set LUA_PATH=%LUA_PATH%;%LR_SYSTREE%\share\lua\%LUA_SHORTV%\?.lua
set LUA_PATH=%LUA_PATH%;%LR_SYSTREE%\share\lua\%LUA_SHORTV%\?\init.lua
set LUA_CPATH=%LR_SYSTREE%\lib\lua\%LUA_SHORTV%\?.dll

call luarocks --version || call :die "Error with LuaRocks installation"
call luarocks list


if not exist "%LR_EXTERNAL%" (
	mkdir "%LR_EXTERNAL%"
	mkdir "%LR_EXTERNAL%\lib"
	mkdir "%LR_EXTERNAL%\include"
)

set PATH=%LR_EXTERNAL%;%PATH%

:: Exports the following variables:
:: (beware of whitespace between & and ^ below)
endlocal & set PATH=%PATH%&^
set LR_SYSTREE=%LR_SYSTREE%&^
set LUA_PATH=%LUA_PATH%&^
set LUA_CPATH=%LUA_CPATH%&^
set LR_EXTERNAL=%LR_EXTERNAL%

echo.
echo ======================================================
echo Installation of LuaRocks %LUAROCKS_VER% done.
echo .
echo LUA_PATH         - %LUA_PATH%
echo LUA_CPATH        - %LUA_CPATH%
echo.
echo LR_EXTERNAL      - %LR_EXTERNAL%
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

