
--- Unix implementation of filesystem and platform abstractions.

local assert, type, table, io, package, math, os, ipairs =
      assert, type, table, io, package, math, os, ipairs

module("luarocks.fs.unix", package.seeall)

local fs = require("luarocks.fs")

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local util = require("luarocks.util")

math.randomseed(os.time())

--- Return an absolute pathname from a potentially relative one.
-- @param pathname string: pathname to convert.
-- @param relative_to string or nil: path to prepend when making
-- pathname absolute, or the current dir in the dir stack if
-- not given.
-- @return string: The pathname converted to absolute.
function absolute_name(pathname, relative_to)
   assert(type(pathname) == "string")
   assert(type(relative_to) == "string" or not relative_to)

   relative_to = relative_to or fs.current_dir()
   if pathname:sub(1,1) == "/" then
      return pathname
   else
      return relative_to .. "/" .. pathname
   end
end

--- Create a wrapper to make a script executable from the command-line.
-- @param file string: Pathname of script to be made executable.
-- @param dest string: Directory where to put the wrapper.
-- @return boolean or (nil, string): True if succeeded, or nil and
-- an error message.
function wrap_script(file, dest)
   assert(type(file) == "string")
   assert(type(dest) == "string")
   
   local base = dir.base_name(file)
   local wrapname = fs.is_dir(dest) and dest.."/"..base or dest
   local wrapper = io.open(wrapname, "w")
   if not wrapper then
      return nil, "Could not open "..wrapname.." for writing."
   end
   wrapper:write("#!/bin/sh\n\n")
   wrapper:write('LUA_PATH="'..package.path..';$LUA_PATH"\n')
   wrapper:write('LUA_CPATH="'..package.cpath..';$LUA_CPATH"\n')
   wrapper:write('export LUA_PATH LUA_CPATH\n')
   wrapper:write('exec "'..dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)..'" -lluarocks.loader "'..file..'" "$@"\n')
   wrapper:close()
   if fs.chmod(wrapname, "0755") then
      return true
   else
      return nil, "Could not make "..wrapname.." executable."
   end
end

--- Check if a file (typically inside path.bin_dir) is an actual binary
-- or a Lua wrapper.
-- @param filename string: the file name with full path.
-- @return boolean: returns true if file is an actual binary
-- (or if it couldn't check) or false if it is a Lua wrapper.
function is_actual_binary(filename)
   if filename:match("%.lua$") then
      return false
   end
   local file = io.open(filename)
   if not file then
      return true
   end
   local first = file:read(2)
   file:close()
   if not first then
      util.printerr("Warning: could not read "..filename)
      return true
   end
   return first ~= "#!"
end

function copy_binary(filename, dest) 
   return fs.copy(filename, dest, "0755")
end
