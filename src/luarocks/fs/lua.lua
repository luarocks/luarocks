
local assert, type, table, io, package, math, os, ipairs =
      assert, type, table, io, package, math, os, ipairs

--- Native Lua implementation of filesystem and platform abstractions,
-- using LuaFileSystem, LZLib, MD5 and LuaCurl.
module("luarocks.fs.lua", package.seeall)

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

local zip_ok, zip = pcall(require, "luarocks.tools.zip")
local lfs_ok, lfs = pcall(require, "lfs")
local curl_ok, curl = pcall(require, "luacurl")
local md5_ok, md5 = pcall(require, "md5")

local tar = require("luarocks.tools.tar")
local patch = require("luarocks.tools.patch")

local dir_stack = {}
            
math.randomseed(os.time())

dir_separator = "/"

local fs_absolute_name,
      fs_copy,
      fs_current_dir,
      fs_dir_stack,
      fs_execute,
      fs_execute_string,
      fs_exists,
      fs_find,
      fs_is_dir,
      fs_is_file,
      fs_make_dir,
      fs_set_time,
      fs_Q

function init_fs_functions(impl)
   fs_absolute_name = impl.absolute_name
   fs_copy = impl.copy
   fs_current_dir = impl.current_dir
   fs_dir_stack = impl.dir_stack
   fs_execute = impl.execute
   fs_execute_string = impl.execute_string
   fs_exists = impl.exists
   fs_find = impl.find
   fs_is_dir = impl.is_dir
   fs_is_file = impl.is_file
   fs_make_dir = impl.make_dir
   fs_set_time = impl.set_time
   fs_Q = impl.Q
end

--- Quote argument for shell processing.
-- Adds single quotes and escapes.
-- @param arg string: Unquoted argument.
-- @return string: Quoted argument.
function Q(arg)
   assert(type(arg) == "string")
   
   -- FIXME Unix-specific
   return "'" .. arg:gsub("\\", "\\\\"):gsub("'", "'\\''") .. "'"
end

--- Test is file/dir is writable.
-- Warning: testing if a file/dir is writable does not guarantee
-- that it will remain writable and therefore it is no replacement
-- for checking the result of subsequent operations.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function is_writable(file)
   assert(file)
   local result
   if fs_is_dir(file) then
      local file2 = file .. '/.tmpluarockstestwritable'
      local fh = io.open(file2, 'w')
      result = fh ~= nil
      if fh then fh:close() end
      os.remove(file2)
   else
      local fh = io.open(file, 'r+')
      result = fh ~= nil
      if fh then fh:close() end
   end
   return result
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

---------------------------------------------------------------------
-- LuaFileSystem functions
---------------------------------------------------------------------

if lfs_ok then

--- Run the given command.
-- The command is executed in the current directory in the dir stack.
-- @param cmd string: No quoting/escaping is applied to the command.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function execute_string(cmd)
   if os.execute(cmd) == 0 then
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

--- Obtain current directory.
-- Uses the module's internal dir stack.
-- @return string: the absolute pathname of the current directory.
function current_dir()
   return lfs.currentdir()
end

--- Change the current directory.
-- Uses the module's internal dir stack. This does not have exact
-- semantics of chdir, as it does not handle errors the same way,
-- but works well for our purposes for now.
-- @param d string: The directory to switch to.
function change_dir(d)
   table.insert(dir_stack, lfs.currentdir())
   lfs.chdir(d)
--local x="CHDIR: " for _,d in ipairs(dir_stack) do x=x.." "..d end print(x)
end

--- Change directory to root.
-- Allows leaving a directory (e.g. for deleting it) in
-- a crossplatform way.
function change_dir_to_root()
   table.insert(dir_stack, lfs.currentdir())
   -- TODO Does this work on Windows?
   lfs.chdir("/")
--local x="CHDIR ROOT: " for _,d in ipairs(dir_stack) do x=x.." "..d end print(x)
end

--- Change working directory to the previous in the dir stack.
-- @return true if a pop ocurred, false if the stack was empty.
function pop_dir()
   local d = table.remove(dir_stack)
--local x="POP DIR: " for _,d in ipairs(dir_stack) do x=x.." "..d end print(x)
   if d then
      lfs.chdir(d)
      return true
   else
      return false
   end
end

--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name does not exist
-- too, they are created as well.
-- @param directory string: pathname of directory to create.
-- @return boolean: true on success, false on failure.
function make_dir(directory)
   assert(type(directory) == "string")
   local path = nil
   for d in directory:gmatch("[^"..dir.separator.."]*"..dir.separator.."*") do
      path = path and path..d or d
      local mode = lfs.attributes(path, "mode")
      if not mode then
         if not lfs.mkdir(path) then
            return false
         end
      elseif mode ~= "directory" then
         return false
      end
   end
   return true
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param d string: pathname of directory to remove.
function remove_dir_if_empty(d)
   assert(d)
   lfs.rmdir(d)
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy(src, dest)
   assert(src and dest)
   local destmode = lfs.attributes(dest, "mode")
   if destmode == "directory" then
      dest = dir.path(dest, dir.base_name(src))
   end
   local src_h, err = io.open(src, "r")
   if not src_h then return nil, err end
   local dest_h, err = io.open(dest, "w+")
   if not dest_h then src_h:close() return nil, err end
   while true do
      local block = src_h:read(8192)
      if not block then break end
      dest_h:write(block)
   end
   src_h:close()
   dest_h:close()
   return true
end

--- Implementation function for recursive copy of directory contents.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure
local function recursive_copy(src, dest)
   local srcmode = lfs.attributes(src, "mode")
      
   if srcmode == "file" then
      local ok = fs_copy(src, dest)
      if not ok then return false end
   elseif srcmode == "directory" then
      local subdir = dir.path(dest, dir.base_name(src))
      fs_make_dir(subdir)
      for file in lfs.dir(src) do
         if file ~= "." and file ~= ".." then
            local ok = recursive_copy(dir.path(src, file), subdir)
            if not ok then return false end
         end
      end
   end
   return true
end

--- Recursively copy the contents of a directory.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy_contents(src, dest)
   assert(src and dest)
   assert(lfs.attributes(src, "mode") == "directory")
   
   for file in lfs.dir(src) do
      local ok = recursive_copy(dir.path(src, file), dest)
      if not ok then
         return false, "Failed copying "..src.." to "..dest
      end
   end
   return true
end

--- Implementation function for recursive removal of directories.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success,
-- or nil and an error message on failure.
local function recursive_delete(src)
   local srcmode = lfs.attributes(src, "mode")
      
   if srcmode == "file" then
      return os.remove(src)
   elseif srcmode == "directory" then
      for file in lfs.dir(src) do
         if file ~= "." and file ~= ".." then
            local ok, err = recursive_delete(dir.path(src, file))
            if not ok then return nil, err end
         end
      end
      local ok, err = lfs.rmdir(src)
      if not ok then return nil, err end
   end
   return true
end

--- Delete a file or a directory and all its contents.
-- For safety, this only accepts absolute paths.
-- @param arg string: Pathname of source
-- @return boolean: true on success, false on failure.
function delete(arg)
   assert(arg)
   assert(arg:sub(1,1) == "/")
   return recursive_delete(arg) or false
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
   for file in lfs.dir(at) do
      if file ~= "." and file ~= ".." then
         table.insert(result, file)
      end
   end
   return result
end

--- Implementation function for recursive find.
-- @param cwd string: Current working directory in recursion.
-- @param prefix string: Auxiliary prefix string to form pathname.
-- @param result table: Array of strings where results are collected.
local function recursive_find(cwd, prefix, result)
   for file in lfs.dir(cwd) do
      if file ~= "." and file ~= ".." then
         local item = prefix .. file
         table.insert(result, item)
         if lfs.attributes(item, "mode") == "directory" then
            recursive_find(item, item..dir_separator, result)
         end
      end
   end
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
   recursive_find(lfs.currentdir(), "", result)
   return result
end

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function exists(file)
   assert(file)
   return type(lfs.attributes(file)) == "table"
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function is_dir(file)
   assert(file)
   return lfs.attributes(file, "mode") == "directory"
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a file, false otherwise.
function is_file(file)
   assert(file)
   return lfs.attributes(file, "mode") == "file"
end

function set_time(file, time)
   return lfs.touch(file, time)
end

end

---------------------------------------------------------------------
-- LuaZip functions
---------------------------------------------------------------------

if zip_ok then

local function zip(zipfile, ...)
   return zip.zip(zipfile, ...)
end

--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function unzip(zipfile)
   assert(zipfile)
   -- FIXME!!!!
   return fs_execute("unzip", zipfile)
end

end

---------------------------------------------------------------------
-- LuaCurl functions
---------------------------------------------------------------------

if curl_ok then

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

   filename = filename or dir.base_name(url)

   local c = curl.new()
   if not c then return false end
   local file = io.open(filename, "wb")
   if not file then return false end
   local ok = c:setopt(curl.OPT_WRITEFUNCTION, function (stream, buffer)
      stream:write(buffer)
      return string.len(buffer)
   end)
   ok = ok and c:setopt(curl.OPT_WRITEDATA, file)
   ok = ok and c:setopt(curl.OPT_BUFFERSIZE, 5000)
   ok = ok and c:setopt(curl.OPT_HTTPHEADER, "Connection: Keep-Alive")
   ok = ok and c:setopt(curl.OPT_URL, url)
   ok = ok and c:setopt(curl.OPT_CONNECTTIMEOUT, 15)
   ok = ok and c:perform()
   ok = ok and c:close()
   file:close()
   return ok
end

end

---------------------------------------------------------------------
-- MD5 functions
---------------------------------------------------------------------

if md5_ok then

--- Check the MD5 checksum for a file.
-- @param file string: The file to be checked.
-- @param md5sum string: The string with the expected MD5 checksum.
-- @return boolean: true if the MD5 checksum for 'file' equals 'md5sum', false if not
-- or if it could not perform the check for any reason.
function check_md5(file, md5sum)
   file = fs_absolute_name(file)
   local file = io.open(file, "r")
   if not file then return false end
   local computed = md5.sumhexa(file:read("*a"))
   file:close()
   if not computed then
      return false
   end
   if computed:match("^"..md5sum) then
      return true
   else
      return false
   end
end

end

--- Apply a patch.
-- @param patchname string: The filename of the patch.
function apply_patch(patchname, patchdata)
   local p, all_ok = patch.read_patch(patchname, patchdata)
   if not all_ok then
      return nil, "Failed reading patch "..patchname
   end
   if p then
      return patch.apply_patch(p, 1)
   end
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
