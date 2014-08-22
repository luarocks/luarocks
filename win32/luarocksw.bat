@echo off
setlocal
SET MYPATH=%~dp0

IF NOT [%1]==[] GOTO LETSGO
ECHO Same as 'luarocks' command, except this
ECHO command will pause after completion, allowing for
ECHO examination of output.
ECHO.
ECHO For LuaRocks help use:
ECHO   LUAROCKS HELP
ECHO.
ECHO OPTIONS specific for LUAROCKSW:
ECHO   REMOVEALL is a command specific to this batch file
ECHO   the option takes a FULL ROCKSPEC filename and then
ECHO   it will strip path, version and extension info from 
ECHO   it before executing the LUAROCKS REMOVE command
ECHO Example:
ECHO    luarocksw remove "c:\somedir\modulename-1.0-1.rockspec"
ECHO will execute:
ECHO    luarocks remove "c:\somedir\modulename-1.0-1.rockspec"
ECHO and will only remove the specific version 1.0 from the
ECHO system.
ECHO    luarocksw removeall "c:\somedir\modulename-1.0-1.rockspec"
ECHO will execute:
ECHO    luarocks remove modulename
ECHO and will remove all versions of this package
ECHO.
GOTO END

:LETSGO
REM if REMOVEALL command then info must be stripped from the parameter
if [%1]==[removeall] goto REMOVEALL

REM execute LuaRocks and wait for results
echo executing: luarocks %*
call "%MYPATH%luarocks" %*
pause
goto END

:REMOVEALL
for /f "delims=-" %%a in ("%~n2") do (
    echo executing: luarocks remove %%a
    "%MYPATH%luarocks" remove "%%a"
    pause
    goto END
)

:END