
local rawset = rawset

--- Proxy module for filesystem and platform abstractions.
-- All code using "fs" code should require "luarocks.fs",
-- and not the various platform-specific implementations.
-- However, see the documentation of the implementation
-- for the API reference.
module("luarocks.fs", package.seeall)

local cfg = require("luarocks.cfg")

local fs_impl = nil
for _, platform in ipairs(cfg.platforms) do
   local ok, result = pcall(require, "luarocks.fs."..platform)
   if ok then
      fs_impl = result
      if fs_impl then
         break
      end
   end
end

local fs_unix = require("luarocks.fs.unix")

local fs_mt = {
   __index = function(t, k)
      local impl = fs_impl and fs_impl[k]
      if not impl then
         impl = fs_unix[k]
      end
      rawset(t, k, impl)
      return impl
   end
}

setmetatable(luarocks.fs, fs_mt)

fs_unix.init_fs_functions(luarocks.fs)
if fs_impl then
   fs_impl.init_fs_functions(luarocks.fs)
end

