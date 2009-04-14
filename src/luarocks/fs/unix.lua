
local assert, type, table, io, package, math, os, ipairs =
      assert, type, table, io, package, math, os, ipairs

--- Unix implementation of filesystem and platform abstractions.
module("luarocks.fs.unix", package.seeall)

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

math.randomseed(os.time())

dir_stack = {}

local fs_absolute_name,
      fs_copy,
      fs_current_dir,
      fs_dir_stack,
      fs_execute,
      fs_execute_string,
      fs_is_dir,
      fs_is_file,
      fs_make_dir,
      fs_exists,
      fs_find,
      fs_Q

function init_fs_functions(impl)
   fs_absolute_name = impl.absolute_name
   fs_copy = impl.copy
   fs_current_dir = impl.current_dir
   fs_dir_stack = impl.dir_stack
   fs_execute = impl.execute
   fs_execute_string = impl.execute_string
   fs_is_dir = impl.is_dir
   fs_is_file = impl.is_file
   fs_make_dir = impl.make_dir
   fs_exists = impl.exists
   fs_find = impl.find
   fs_Q = impl.Q
end

--- Quote argument for shell processing.
-- Adds single quotes and escapes.
-- @param arg string: Unquoted argument.
-- @return string: Quoted argument.
function Q(arg)
   assert(type(arg) == "string")

   return "'" .. arg:gsub("\\", "\\\\"):gsub("'", "'\\''") .. "'"
end

--- Obtain current directory.
-- Uses the module's internal dir stack.
-- @return string: the absolute pathname of the current directory.
function current_dir()
   local current = os.getenv("PWD")
   if not current then
      local pipe = io.popen("pwd")
      current = pipe:read("*l")
      pipe:close()
   end
   for _, d in ipairs(fs_dir_stack) do
      current = fs_absolute_name(d, current)
   end
   return current
end

--- Run the given command.
-- The command is executed in the current directory in the dir stack.
-- @param cmd string: No quoting/escaping is applied to the command.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function execute_string(cmd)
   if os.execute("cd " .. fs_Q(fs_current_dir()) .. " && " .. cmd) == 0 then
      return true
   else
      return false
   end
end

--- Run the given command, quoting its arguments.
-- The command is executed in the current directory in the dir stack.
-- @param command string: The command to be executed. No quoting/escaping
-- is applied.
-- @param ... Strings containing additional arguments, which are quoted.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function execute(command, ...)
   assert(type(command) == "string")
   
   for _, arg in ipairs({...}) do
      assert(type(arg) == "string")
      command = command .. " " .. fs_Q(arg)
   end
   return fs_execute_string(command)
end

--- Change the current directory.
-- Uses the module's internal dir stack. This does not have exact
-- semantics of chdir, as it does not handle errors the same way,
-- but works well for our purposes for now.
-- @param d string: The directory to switch to.
function change_dir(d)
   assert(type(d) == "string")
   table.insert(fs_dir_stack, d)
end

--- Change directory to root.
-- Allows leaving a directory (e.g. for deleting it) in
-- a crossplatform way.
function change_dir_to_root()
   table.insert(fs_dir_stack, "/")
end

--- Change working directory to the previous in the dir stack.
function pop_dir()
   local d = table.remove(fs_dir_stack)
   return d ~= nil
end

--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name does not exist
-- too, they are created as well.
-- @param d string: pathname of directory to create.
-- @return boolean: true on success, false on failure.
function make_dir(d)
   assert(d)
   return fs_execute("mkdir -p", d)
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param dir string: pathname of directory to remove.
function remove_dir_if_empty(d)
   assert(d)
   fs_execute_string("rmdir "..fs_Q(d).." 1> /dev/null 2> /dev/null")
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy(src, dest)
   assert(src and dest)
   if fs_execute("cp", src, dest) then
      return true
   else
      return false, "Failed copying "..src.." to "..dest
   end
end

--- Recursively copy the contents of a directory.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy_contents(src, dest)
   assert(src and dest)
   if fs_execute_string("cp -pPR "..fs_Q(src).."/* "..fs_Q(dest).." 1> /dev/null 2>/dev/null") then
      return true
   else
      return false, "Failed copying "..src.." to "..dest
   end
end

--- Delete a file or a directory and all its contents.
-- For safety, this only accepts absolute paths.
-- @param arg string: Pathname of source
-- @return boolean: true on success, false on failure.
function delete(arg)
   assert(arg)
   assert(arg:sub(1,1) == "/")
   return fs_execute_string("rm -rf " .. fs_Q(arg) .. " 1> /dev/null 2>/dev/null")
end

--- List the contents of a directory. 
-- @param at string or nil: directory to list (will be the current
-- directory if none is given).
-- @return table: an array of strings with the filenames representing
-- the contents of a directory.
function list_dir(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs_current_dir()
   end
   if not fs_is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen("cd "..fs_Q(at).." && ls")
   for file in pipe:lines() do
      table.insert(result, file)
   end
   pipe:close()
   return result
end

--- Recursively scan the contents of a directory. 
-- @param at string or nil: directory to scan (will be the current
-- directory if none is given).
-- @return table: an array of strings with the filenames representing
-- the contents of a directory.
function find(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs_current_dir()
   end
   if not fs_is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen("cd "..fs_Q(at).." && find * 2>/dev/null") 
   for file in pipe:lines() do
      table.insert(result, file)
   end
   pipe:close()
   return result
end

--- Compress files in a .zip archive.
-- @param zipfile string: pathname of .zip archive to be created.
-- @param ... Filenames to be stored in the archive are given as
-- additional arguments.
-- @return boolean: true on success, false on failure.
function zip(zipfile, ...)
   return fs_execute("zip -r", zipfile, ...)
end

--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function unzip(zipfile)
   assert(zipfile)
   return fs_execute("unzip", zipfile)
end

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function exists(file)
   assert(file)
   return fs_execute("test -r", file)
end

--- Test is file/dir is writable.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function is_writable(file)
   assert(file)
   return fs_execute("test -w", file)
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function is_dir(file)
   assert(file)
   return fs_execute("test -d", file)
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a regular file, false otherwise.
function is_file(file)
   assert(file)
   return fs_execute("test -f", file)
end

--- Download a remote file.
-- @param url string: URL to be fetched.
-- @param filename string or nil: this function attempts to detect the
-- resulting local filename of the remote file as the basename of the URL;
-- if that is not correct (due to a redirection, for example), the local
-- filename can be given explicitly as this second argument.
-- @return boolean: true on success, false on failure.
function download(url, filename)
   assert(type(url) == "string")
   assert(type(filename) == "string" or not filename)

   if cfg.downloader == "wget" then
      local wget_cmd = "wget --user-agent="..cfg.user_agent.." --quiet --continue "
      if filename then
         return fs_execute(wget_cmd.." --output-document ", filename, url)
      else
         return fs_execute(wget_cmd, url)
      end
   elseif cfg.downloader == "curl" then
      filename = filename or dir.base_name(url)
      return fs_execute_string("curl --user-agent "..cfg.user_agent.." "..fs_Q(url).." 2> /dev/null 1> "..fs_Q(filename))
   end
end

--- Create a temporary directory.
-- @param name string: name pattern to use for avoiding conflicts
-- when creating temporary directory.
-- @return string or nil: name of temporary directory or nil on failure.
function make_temp_dir(name)
   assert(type(name) == "string")

   local temp_dir = (os.getenv("TMP") or "/tmp") .. "/luarocks_" .. name:gsub(dir.separator, "_") .. "-" .. tostring(math.floor(math.random() * 10000))
   if fs_make_dir(temp_dir) then
      return temp_dir
   else
      return nil
   end
end

function chmod(pathname, mode)
  return fs_execute("chmod "..mode, pathname)
end

--- Apply a patch.
-- @param patchname string: The filename of the patch.
function apply_patch(patchname)
   return fs_execute("patch -p1 -f -i ", patchname)
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function unpack_archive(archive)
   assert(type(archive) == "string")

   local ok
   if archive:match("%.tar%.gz$") or archive:match("%.tgz$") then
      -- ok = fs_execute("tar zxvpf ", archive)
         ok = fs_execute_string("gunzip -c "..archive.."|tar -xf -")
   elseif archive:match("%.tar%.bz2$") then
      -- ok = fs_execute("tar jxvpf ", archive)
         ok = fs_execute_string("bunzip2 -c "..archive.."|tar -xf -")
   elseif archive:match("%.zip$") then
      ok = fs_execute("unzip ", archive)
   elseif archive:match("%.lua$") or archive:match("%.c$") then
      -- Ignore .lua and .c files; they don't need to be extracted.
      return true
   else
      local ext = archive:match(".*(%..*)")
      return false, "Unrecognized filename extension "..(ext or "")
   end
   if not ok then
      return false, "Failed extracting "..archive
   end
   return true
end

--- Check the MD5 checksum for a file.
-- @param file string: The file to be checked.
-- @param md5sum string: The string with the expected MD5 checksum.
-- @return boolean: true if the MD5 checksum for 'file' equals 'md5sum', false if not
-- or if it could not perform the check for any reason.
function check_md5(file, md5sum)
   file = fs_absolute_name(file)
   local computed
   if cfg.md5checker == "md5sum" then
      local pipe = io.popen("md5sum "..file)
      computed = pipe:read("*l"):gsub("[^%x]+", "")
      pipe:close()
      if computed then
         computed = computed:sub(1,32)
      end
   elseif cfg.md5checker == "openssl" then
      local pipe = io.popen("openssl md5 "..file)
      computed = pipe:read("*l")
      pipe:close()
      if computed then
         computed = computed:sub(-32)
      end
   elseif cfg.md5checker == "md5" then
      local pipe = io.popen("md5 "..file)
      computed = pipe:read("*l")
      pipe:close()
      if computed then
         computed = computed:sub(-32)
      end
   end
   if not computed then
      return false
   end
   if computed:match("^"..md5sum) then
      return true
   else
      return false
   end
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

   relative_to = relative_to or fs_current_dir()
   if pathname:sub(1,1) == "/" then
      return pathname
   else
      return relative_to .. "/" .. pathname
   end
end

--- Split protocol and path from an URL or local pathname.
-- URLs should be in the "protocol://path" format.
-- For local pathnames, "file" is returned as the protocol.
-- @param url string: an URL or a local pathname.
-- @return string, string: the protocol, and the absolute pathname without the protocol.
function split_url(url)
   assert(type(url) == "string")
   
   local protocol, pathname = url:match("^([^:]*)://(.*)")
   if not protocol then
      protocol = "file"
      pathname = url
   end
   if protocol == "file" then
      pathname = fs_absolute_name(pathname)
   end
   return protocol, pathname
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
   local wrapname = dest.."/"..base
   local wrapper = io.open(wrapname, "w")
   if not wrapper then
      return nil, "Could not open "..wrapname.." for writing."
   end
   wrapper:write("#!/bin/sh\n\n")
   wrapper:write('LUA_PATH="'..package.path..';$LUA_PATH"\n')
   wrapper:write('LUA_CPATH="'..package.cpath..';$LUA_CPATH"\n')
   wrapper:write('export LUA_PATH LUA_CPATH\n')
   wrapper:write('exec "'..dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)..'" -lluarocks.require "'..file..'" "$@"\n')
   wrapper:close()
   if fs_execute("chmod +x",wrapname) then
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
   if file then
      local found = false
      local first = file:read()
      if first:match("#!.*lua") then
         found = true
      elseif first:match("#!/bin/sh") then
         local line = file:read()
         line = file:read()
         if not(line and line:match("LUA_PATH")) then
            found = true
         end
      end
      file:close()
      if found then
         return false
      else
         return true
      end
   else
      return true
   end
   return false
end

function copy_binary(filename, dest) 
   return fs_copy(filename, dest)
end

