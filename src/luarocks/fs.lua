
--- Proxy module for filesystem and platform abstractions.
-- All code using "fs" code should require "luarocks.fs",
-- and not the various platform-specific implementations.
-- However, see the documentation of the implementation
-- for the API reference.

local pairs = pairs

--module("luarocks.fs", package.seeall)
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
    print("\nos.execute: ", cmd)
    local code = pack(old_exec(cmd))
    print("Results: "..tostring(code.n))
    for i = 1,code.n do
      print("  "..tostring(i).." ("..type(code[i]).."): "..tostring(code[i]))
    end
    return unpack(code, 1, code.n)    
  end
end
if cfg.verbose then fs.verbose() end

local function load_fns(fs_table)
   for name, fn in pairs(fs_table) do
      if not fs[name] then
         fs[name] = fn
      end
   end
end

-- Load platform-specific functions
local loaded_platform = nil
for _, platform in ipairs(cfg.platforms) do
   local ok, fs_plat = pcall(require, "luarocks.fs."..platform)
   if ok and fs_plat then
      loaded_platform = platform
      load_fns(fs_plat)
      break
   end
end

-- Load platform-independent pure-Lua functionality
local fs_lua = require("luarocks.fs.lua")
load_fns(fs_lua)

-- Load platform-specific fallbacks for missing Lua modules
local ok, fs_plat_tools = pcall(require, "luarocks.fs."..loaded_platform..".tools")
if ok and fs_plat_tools then load_fns(fs_plat_tools) end


return fs
