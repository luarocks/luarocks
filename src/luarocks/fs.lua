
--- Proxy module for filesystem and platform abstractions.
-- All code using "fs" code should require "luarocks.fs",
-- and not the various platform-specific implementations.
-- However, see the documentation of the implementation
-- for the API reference.

local pairs = pairs

module("luarocks.fs", package.seeall)

local cfg = require("luarocks.cfg")

local function load_fns(fs_table)
   for name, fn in pairs(fs_table) do
      if not _M[name] then
         _M[name] = fn
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

-- uncomment below for further debugging than 'verbose=true' in config file
-- code below will also catch commands outside of fs.execute()
-- especially uses of io.popen().
--[[
old_exec = os.execute
os.execute = function(cmd)
  print("os.execute: ", cmd)
  return old_exec(cmd)
end
old_popen = io.popen
io.popen = function(one, two)
  if two == nil then
    print("io.popen: ", one)
  else
    print("io.popen: ", one, "Mode:", two)
  end
  return old_popen(one, two)
end
--]]
