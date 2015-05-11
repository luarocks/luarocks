--- Windows implementation of filesystem and platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
--module("luarocks.fs.win32", package.seeall)
local win32 = {}

local fs = require("luarocks.fs")

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")
local util = require("luarocks.util")

-- Monkey patch io.popen and os.execute to make sure quoting
-- works as expected.
-- See http://lua-users.org/lists/lua-l/2013-11/msg00367.html
local _prefix = "type NUL && "
local _popen, _execute = io.popen, os.execute
io.popen = function(cmd, ...) return _popen(_prefix..cmd, ...) end
os.execute = function(cmd, ...) return _execute(_prefix..cmd, ...) end


--- Annotate command string for quiet execution.
-- @param cmd string: A command-line string.
-- @return string: The command-line, with silencing annotation.
function win32.quiet(cmd)
   return cmd.." 2> NUL 1> NUL"
end


local win_escape_chars = {
  ["%"] = "%%",
  ['"'] = '\\"',
}

local function q_escaper(bs, q)
  return ("\\"):rep(2*#bs-1) .. (q or "\\")
end

local function p_escaper(bs)
   return bs .. bs .. '"%"'
end

--- Quote argument for shell processing. Fixes paths on Windows.
-- Adds double quotes and escapes.
-- @param arg string: Unquoted argument.
-- @return string: Quoted argument.
function win32.Q(arg)
   assert(type(arg) == "string")
   -- Quote DIR for Windows
   if arg:match("^[%.a-zA-Z]?:?[\\/]")  then
      arg = arg:gsub("/", "\\")
   end
   if arg == "\\" then
      return '\\' -- CHDIR needs special handling for root dir
   end
    -- URLs and anything else
   arg = arg:gsub('(\\+)(")', q_escaper)
   arg = arg:gsub('(\\+)$', q_escaper)
   arg = arg:gsub('"', win_escape_chars)
   arg = arg:gsub('(\\*)%%', p_escaper)
   return '"' .. arg .. '"'
end

--- Quote argument for shell processing in batch files.
-- Adds double quotes and escapes.
-- @param arg string: Unquoted argument.
-- @return string: Quoted argument.
function win32.Qb(arg)
   assert(type(arg) == "string")
   -- Quote DIR for Windows
   if arg:match("^[%.a-zA-Z]?:?[\\/]")  then
      arg = arg:gsub("/", "\\")
   end
   if arg == "\\" then
      return '\\' -- CHDIR needs special handling for root dir
   end
   -- URLs and anything else
   arg = arg:gsub('(\\+)(")', q_escaper)
   arg = arg:gsub('(\\+)$', q_escaper)
   arg = arg:gsub('[%%"]', win_escape_chars)
   return '"' .. arg .. '"'
end

--- Return an absolute pathname from a potentially relative one.
-- @param pathname string: pathname to convert.
-- @param relative_to string or nil: path to prepend when making
-- pathname absolute, or the current dir in the dir stack if
-- not given.
-- @return string: The pathname converted to absolute.
function win32.absolute_name(pathname, relative_to)
   assert(type(pathname) == "string")
   assert(type(relative_to) == "string" or not relative_to)

   relative_to = relative_to or fs.current_dir()
   -- FIXME I'm not sure this first \\ should be there at all.
   -- What are the Windows rules for drive letters?
   if pathname:match("^[\\.a-zA-Z]?:?[\\/]") then
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
function win32.wrap_script(file, dest, name, version)
   assert(type(file) == "string")
   assert(type(dest) == "string")

   local base = dir.base_name(file)
   local wrapname = fs.is_dir(dest) and dest.."/"..base or dest
   wrapname = wrapname..".bat"
   local lpath, lcpath = cfg.package_paths()
   local wrapper = io.open(wrapname, "w")
   if not wrapper then
      return nil, "Could not open "..wrapname.." for writing."
   end
   wrapper:write("@echo off\n")
   local lua = dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)
   local ppaths = "package.path="..util.LQ(lpath..";").."..package.path; package.cpath="..util.LQ(lcpath..";").."..package.cpath"
   local addctx = "local k,l,_=pcall(require,"..util.LQ("luarocks.loader")..") _=k and l.add_context("..util.LQ(name)..","..util.LQ(version)..")"
   wrapper:write(fs.Qb(lua)..' -e '..fs.Qb(ppaths)..' -e '..fs.Qb(addctx)..' '..fs.Qb(file)..' %*\n')
   wrapper:write("exit /b %ERRORLEVEL%\n")
   wrapper:close()
   return true
end

function win32.is_actual_binary(name)
   name = name:lower()
   if name:match("%.bat$") or name:match("%.exe$") then
      return true
   end
   return false
end

function win32.copy_binary(filename, dest) 
   local ok, err = fs.copy(filename, dest)
   if not ok then
      return nil, err
   end
   local exe_pattern = "%.[Ee][Xx][Ee]$"
   local base = dir.base_name(filename)
   dest = dir.dir_name(dest)
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

function win32.chmod(filename, mode)
   return true
end

function win32.get_permissions(filename)
   return ""
end

--- Move a file on top of the other.
-- The new file ceases to exist under its original name,
-- and takes over the name of the old file.
-- On Windows this is done by removing the original file and
-- renaming the new file to its original name.
-- @param old_file The name of the original file,
-- which will be the new name of new_file.
-- @param new_file The name of the new file,
-- which will replace old_file.
-- @return boolean or (nil, string): True if succeeded, or nil and
-- an error message.
function win32.replace_file(old_file, new_file)
   os.remove(old_file)
   return os.rename(new_file, old_file)
end

--- Test is file/dir is writable.
-- Warning: testing if a file/dir is writable does not guarantee
-- that it will remain writable and therefore it is no replacement
-- for checking the result of subsequent operations.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function win32.is_writable(file)
   assert(file)
   file = dir.normalize(file)
   local result
   local tmpname = 'tmpluarockstestwritable.deleteme'
   if fs.is_dir(file) then
      local file2 = dir.path(file, tmpname)
      local fh = io.open(file2, 'wb')
      result = fh ~= nil
      if fh then fh:close() end
      if result then
         -- the above test might give a false positive when writing to
         -- c:\program files\ because of VirtualStore redirection on Vista and up
         -- So check whether it's really there
         result = fs.exists(file2)
      end
      os.remove(file2)
   else
      local fh = io.open(file, 'r+b')
      result = fh ~= nil
      if fh then fh:close() end
   end
   return result
end

function win32.tmpname()
   return os.getenv("TMP")..os.tmpname()
end

return win32
