
local static_flags = {}
package.loaded["luarocks.static_flags"] = static_flags

local util = require("luarocks.util")

util.add_run_function(static_flags)

return static_flags
