
--- Build back-end for xmake-based modules.
local xmake = {}

local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")

--- Driver function for the "xmake" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors occurred,
-- nil and an error message otherwise.
function xmake.run(rockspec, no_install)
   assert(rockspec:type() == "rockspec")
   local build = rockspec.build
   local variables = build.variables or {}

   print("xmake.run", rockspec, no_install)
   return true
end

return xmake
