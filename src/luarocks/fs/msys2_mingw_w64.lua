--- MSYS2 + Mingw-w64 implementation of filesystem and platform abstractions.
local msys2_mingw_w64 = {}

local unix_tools = require("luarocks.fs.unix.tools")

msys2_mingw_w64.zip = unix_tools.zip
msys2_mingw_w64.unzip = unix_tools.unzip
msys2_mingw_w64.gunzip = unix_tools.gunzip
msys2_mingw_w64.bunzip2 = unix_tools.bunzip2
msys2_mingw_w64.copy_contents = unix_tools.copy_contents

return msys2_mingw_w64
