--- NetBSD implementation of filesystem and platform abstractions.
local netbsd = {}

local fs = require("luarocks.fs")

function netbsd.init()
    local uz=io.open("/usr/bin/unzip", "r")
    if uz ~= nil then 
        io.close(uz) 
        fs.set_tool_available("unzip", true)
    end
end

return netbsd
