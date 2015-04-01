@echo off
Setlocal EnableDelayedExpansion EnableExtensions

if not defined LUAROCKS_REPO set LUAROCKS_REPO=http://rocks.moonscript.org

appveyor DownloadFile %LUAROCKS_REPO%/stdlib-41.0.0-1.src.rock
luarocks build stdlib

endlocal
