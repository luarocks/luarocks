@ECHO OFF
SETLOCAL
"%LUA_DEV%\lua" "%LUA_DEV%\luarocks-admin.lua" %*
ENDLOCAL
