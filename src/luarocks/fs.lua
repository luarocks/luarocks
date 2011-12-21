
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

