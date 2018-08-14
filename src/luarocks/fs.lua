
--- Proxy module for filesystem and platform abstractions.
-- All code using "fs" code should require "luarocks.fs",
-- and not the various platform-specific implementations.
-- However, see the documentation of the implementation
-- for the API reference.

local pairs = pairs

local fs = {}
package.loaded["luarocks.fs"] = fs

local cfg = require("luarocks.cfg")

local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local unpack = table.unpack or unpack

local old_popen, old_exec
fs.verbose = function()    -- patch io.popen and os.execute to display commands in verbose mode
  if old_popen or old_exec then return end
  old_popen = io.popen
  io.popen = function(one, two)
    if two == nil then
      print("\nio.popen: ", one)
    else
      print("\nio.popen: ", one, "Mode:", two)
    end
    return old_popen(one, two)
  end
  
  old_exec = os.execute
  os.execute = function(cmd)
    -- redact api keys if present
    print("\nos.execute: ", (cmd:gsub("(/api/[^/]+/)([^/]+)/", function(cap, key) return cap.."<redacted>/" end)) )
    local code = pack(old_exec(cmd))
    print("Results: "..tostring(code.n))
    for i = 1,code.n do
      print("  "..tostring(i).." ("..type(code[i]).."): "..tostring(code[i]))
    end
    return unpack(code, 1, code.n)    
  end
end
if cfg.verbose then fs.verbose() end

return fs
