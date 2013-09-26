@ECHO OFF
ECHO.
IF "%1"=="" GOTO GOEXIT

:PACKIT
mkdir %1
mkdir %1\test
mkdir %1\src
xcopy /S/E .\test\*.* %1\test
xcopy /S/E .\src\*.* %1\src
xcopy /S/E .\win32\*.* %1
copy *.* %1
del %1\configure
del %1\makedist
del %1\Makefile
del %1\win32pack.bat
cd %1

GOTO:EOF

:GOEXIT
ECHO.
ECHO This command creates a directory with an installable LuaRocks structure. This is
ECHO a workaround for the packaging script being a unix shell script.
ECHO.
ECHO To install LuaRocks on Windows from a Git repo use the following commands: 
ECHO.
ECHO    %0 ^<TARGET_DIR^>
ECHO    install /?
ECHO.
ECHO Then follow instructions displayed to install LuaRocks
ECHO.

