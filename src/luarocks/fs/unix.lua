--- Unix implementation of filesystem and platform abstractions.
local unix = {}

local fs = require("luarocks.fs")

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local util = require("luarocks.util")

--- Annotate command string for quiet execution.
-- @param cmd string: A command-line string.
-- @return string: The command-line, with silencing annotation.
function unix.quiet(cmd)
   return cmd.." 1> /dev/null 2> /dev/null"
end

--- Annotate command string for execution with quiet stderr.
-- @param cmd string: A command-line string.
-- @return string: The command-line, with stderr silencing annotation.
function unix.quiet_stderr(cmd)
   return cmd.." 2> /dev/null"
end

--- Quote argument for shell processing.
-- Adds single quotes and escapes.
-- @param arg string: Unquoted argument.
-- @return string: Quoted argument.
function unix.Q(arg)
   assert(type(arg) == "string")
   return "'" .. arg:gsub("'", "'\\''") .. "'"
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

--- Return the root directory for the given path.
-- In Unix, root is always "/".
-- @param pathname string: pathname to use.
-- @return string: The root of the given pathname.
function unix.root_of(_)
   return "/"
end

--- Create a wrapper to make a script executable from the command-line.
-- @param file string: Pathname of script to be made executable.
-- @param dest string: Directory where to put the wrapper.
-- @param name string: rock name to be used in loader context.
-- @param version string: rock version to be used in loader context.
-- @return boolean or (nil, string): True if succeeded, or nil and
-- an error message.
function unix.wrap_script(file, dest, deps_mode, name, version, ...)
   assert(type(file) == "string" or not file)
   assert(type(dest) == "string")
   assert(type(deps_mode) == "string")
   assert(type(name) == "string" or not name)
   assert(type(version) == "string" or not version)
   
   local wrapname = fs.is_dir(dest) and dest.."/"..dir.base_name(file) or dest

   local wrapper = io.open(wrapname, "w")
   if not wrapper then
      return nil, "Could not open "..wrapname.." for writing."
   end

   local lpath, lcpath = path.package_paths(deps_mode)

   local luainit = {
      "package.path="..util.LQ(lpath..";").."..package.path",
      "package.cpath="..util.LQ(lcpath..";").."..package.cpath",
   }
   if dest == "luarocks" or dest == "luarocks-admin" then
      luainit = {
         "package.path="..util.LQ(package.path),
         "package.cpath="..util.LQ(package.cpath),
      }
   end
   if name and version then
      local addctx = "local k,l,_=pcall(require,"..util.LQ("luarocks.loader")..") _=k " ..
                     "and l.add_context("..util.LQ(name)..","..util.LQ(version)..")"
      table.insert(luainit, addctx)
   end

   local argv = {
      fs.Q(dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)),
      file and fs.Q(file) or "",
      ...
   }

   wrapper:write("#!/bin/sh\n\n")
   wrapper:write("LUAROCKS_SYSCONFDIR="..fs.Q(cfg.sysconfdir) .. " ")
   wrapper:write("LUA_INIT="..fs.Q(table.concat(luainit, ";")).." ")
   wrapper:write("exec "..table.concat(argv, " ")..' "$@"\n')
   wrapper:close()

   if fs.set_permissions(wrapname, "exec", "all") then
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
      cmd.log("could not read "..filename, true)
      return true
   end
   return first ~= "#!"
end

function unix.copy_binary(filename, dest) 
   return fs.copy(filename, dest, "exec")
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

function unix.current_user()
   return os.getenv("USER")
end

function unix.export_cmd(var, val)
   return ("export %s='%s'"):format(var, val)
end

--- Moderate the given permissions based on the local umask
-- @param perms string: permissions to moderate
-- @return string: the moderated permissions
function unix._unix_moderate_permissions(perms)
   local octal_to_rwx = {
      ["0"] = "---",
      ["1"] = "--x",
      ["2"] = "-w-",
      ["3"] = "-wx",
      ["4"] = "r--",
      ["5"] = "r-x",
      ["6"] = "rw-",
      ["7"] = "rwx",
   }
   local rwx_to_octal = {}
   for octal, rwx in pairs(octal_to_rwx) do
      rwx_to_octal[rwx] = octal
   end

   local umask = fs._unix_umask()

   local moderated_perms = ""
   for i = 1, 3 do
      local p_rwx = octal_to_rwx[perms:sub(i, i)]
      local u_rwx = octal_to_rwx[umask:sub(i, i)]
      local new_perm = ""
      for j = 1, 3 do
         local p_val = p_rwx:sub(j, j)
         local u_val = u_rwx:sub(j, j)
         if p_val == u_val then
            new_perm = new_perm .. "-"
         else
            new_perm = new_perm .. p_val
         end
      end
      moderated_perms = moderated_perms .. rwx_to_octal[new_perm]
   end
   return moderated_perms
end

return unix
