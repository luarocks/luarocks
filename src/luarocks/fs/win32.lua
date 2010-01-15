--- Windows implementation of filesystem and platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
module("luarocks.fs.win32", package.seeall)

local fs = require("luarocks.fs")

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

--- Quote argument for shell processing. Fixes paths on Windows.
-- Adds single quotes and escapes.
-- @param arg string: Unquoted argument.
-- @return string: Quoted argument.
function Q(arg)
   assert(type(arg) == "string")
   -- Quote DIR for Windows
    if arg:match("^[\.a-zA-Z]?:?[\\/]")  then
        return '"' .. arg:gsub("/", "\\"):gsub('"', '\\"') .. '"'
    end
    -- URLs and anything else
   return '"' .. arg:gsub('"', '\\"') .. '"'
end

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
   if pathname:match("^[\.a-zA-Z]?:?[\\/]") then
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
   wrapname = wrapname..".bat"
   local wrapper = io.open(wrapname, "w")
   if not wrapper then
      return nil, "Could not open "..wrapname.." for writing."
   end
   wrapper:write("@echo off\n")
   wrapper:write("setlocal\n")
   wrapper:write('set LUA_PATH='..package.path..";%LUA_PATH%\n")
   wrapper:write('set LUA_CPATH='..package.cpath..";%LUA_CPATH%\n")
   wrapper:write('"'..dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)..'" -lluarocks.loader "'..file..'" %*\n')
   wrapper:write("endlocal\n")
   wrapper:close()
   return true
end

function is_actual_binary(name)
   name = name:lower()
   if name:match("%.bat$") or name:match("%.exe$") then
      return true
   end
   return false
end

function copy_binary(filename, dest) 
   local ok, err = fs.copy(filename, dest)
   if not ok then
      return nil, err
   end
   local exe_pattern = "%.[Ee][Xx][Ee]$"
   local base = dir.base_name(filename)
   local dest = dir.dir_name(dest)
   if base:match(exe_pattern) then
      base = base:gsub(exe_pattern, ".lua")
      local helpname = dest.."/"..base
      local helper = io.open(helpname, "w")
      if not helper then
         return nil, "Could not open "..helpname.." for writing."
      end
      helper:write('package.path=\"'..package.path:gsub("\\","\\\\")..';\"..package.path\n')
      helper:write('package.cpath=\"'..package.path:gsub("\\","\\\\")..';\"..package.cpath\n')
      helper:close()
   end
   return true
end
