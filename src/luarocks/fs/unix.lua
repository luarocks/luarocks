
--- Unix implementation of filesystem and platform abstractions.
--module("luarocks.fs.unix", package.seeall)
local unix = {}

local fs = require("luarocks.fs")

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")
local util = require("luarocks.util")

math.randomseed(os.time())

--- Annotate command string for quiet execution.
-- @param cmd string: A command-line string.
-- @return string: The command-line, with silencing annotation.
function unix.quiet(cmd)
   return cmd.." 1> /dev/null 2> /dev/null"
end

--- Return an absolute pathname from a potentially relative one.
-- @param pathname string: pathname to convert.
-- @param relative_to string or nil: path to prepend when making
-- pathname absolute, or the current dir in the dir stack if
-- not given.
-- @return string: The pathname converted to absolute.
function unix.absolute_name(pathname, relative_to)
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
-- @param name string: rock name to be used in loader context.
-- @param version string: rock version to be used in loader context.
-- @return boolean or (nil, string): True if succeeded, or nil and
-- an error message.
function unix.wrap_script(file, dest, name, version)
   assert(type(file) == "string")
   assert(type(dest) == "string")
   
   local base = dir.base_name(file)
   local wrapname = fs.is_dir(dest) and dest.."/"..base or dest
   local lpath, lcpath = cfg.package_paths()
   local wrapper = io.open(wrapname, "w")
   if not wrapper then
      return nil, "Could not open "..wrapname.." for writing."
   end
   wrapper:write("#!/bin/sh\n\n")
   local lua = dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)
   local ppaths = "package.path="..util.LQ(lpath..";").."..package.path; package.cpath="..util.LQ(lcpath..";").."..package.cpath"
   local addctx = "local k,l,_=pcall(require,"..util.LQ("luarocks.loader")..") _=k and l.add_context("..util.LQ(name)..","..util.LQ(version)..")"
   wrapper:write('exec '..fs.Q(lua)..' -e '..fs.Q(ppaths)..' -e '..fs.Q(addctx)..' '..fs.Q(file)..' "$@"\n')
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
function unix.is_actual_binary(filename)
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

function unix.copy_binary(filename, dest) 
   return fs.copy(filename, dest, "0755")
end

--- Move a file on top of the other.
-- The new file ceases to exist under its original name,
-- and takes over the name of the old file.
-- On Unix this is done through a single rename operation.
-- @param old_file The name of the original file,
-- which will be the new name of new_file.
-- @param new_file The name of the new file,
-- which will replace old_file.
-- @return boolean or (nil, string): True if succeeded, or nil and
-- an error message.
function unix.replace_file(old_file, new_file)
   return os.rename(new_file, old_file)
end

function unix.tmpname()
   return os.tmpname()
end

return unix
