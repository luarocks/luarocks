--- FreeBSD implementation of filesystem and platform abstractions.
local freebsd = {}

local fs = require("luarocks.fs")

function freebsd.init()
   fs.set_tool_available("zip", true)
   fs.set_tool_available("unzip", true)
end

return freebsd
