--- Windows implementation of filesystem and platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
module("luarocks.fs.win32", package.seeall)

local cfg = require("luarocks.cfg")

local fs_base_name,
      fs_copy,
      fs_current_dir,
      fs_execute,
      fs_execute_string,
      fs_is_dir,
      fs_make_path,
      fs_Q

function init_fs_functions(impl)
   fs_base_name = impl.base_name
   fs_copy = impl.copy
   fs_current_dir = impl.current_dir
   fs_execute = impl.execute
   fs_execute_string = impl.execute_string
   fs_is_dir = impl.is_dir
   fs_make_path = impl.make_path
   fs_Q = impl.Q
end

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

local function command_at(dir, cmd)
   local drive = dir:match("^([A-Za-z]:)")
   cmd = "cd " .. fs_Q(dir) .. " & " .. cmd
   if drive then
      cmd = drive .. " & " .. cmd
   end
   return cmd
end

--- Run the given command.
-- The command is executed in the current directory in the dir stack.
-- @param cmd string: No quoting/escaping is applied to the command.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function execute_string(cmd)
   if os.execute(command_at(fs_current_dir(), cmd)) == 0 then
      return true
   else
      return false
   end
end

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function exists(file)
   assert(file)
   return fs_execute("if not exist " .. fs_Q(file) ..
                     " invalidcommandname 2>NUL 1>NUL")
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function is_dir(file)
   assert(file)
   return fs_execute("chdir /D " .. fs_Q(file) .. " 2>NUL 1>NUL")
end

--- Test is file/dir is writable.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function is_writable(file)
   assert(file)
   local result
   if is_dir(file) then
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


--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name does not exist
-- too, they are created as well.
-- @param dir string: pathname of directory to create.
-- @return boolean: true on success, false on failure.
function make_dir(dir)
   assert(dir)
   fs_execute("mkdir "..fs_Q(dir).." 1> NUL 2> NUL")
   return 1
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param dir string: pathname of directory to remove.
function remove_dir_if_empty(dir)
   assert(dir)
   fs_execute_string("rmdir "..fs_Q(dir).." 1> NUL 2> NUL")
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy(src, dest)
   assert(src and dest)
   if dest:match("[/\\]$") then dest = dest:sub(1, -2) end
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
   if fs_execute_string("cp -a "..src.."\\*.* "..fs_Q(dest).." 1> NUL 2> NUL") then
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
   assert(arg:match("^[\a-zA-Z]?:?[\\/]"))
   fs_execute("chmod a+rw -R ", arg)
   return fs_execute_string("rm -rf " .. fs_Q(arg) .. " 1> NUL 2> NUL")
end

--- List the contents of a directory. 
-- @param at string or nil: directory to list (will be the current
-- directory if none is given).
-- @return table: an array of strings with the filenames representing
-- the contents of a directory.
function dir(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs_current_dir()
   end
   if not fs_is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen(command_at(at, "ls"))
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
-- the contents of a directory. Paths are returned with forward slashes.
function find(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs_current_dir()
   end
   if not fs_is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen(command_at(at, "find 2> NUL")) 
   for file in pipe:lines() do
      -- Windows find is a bit different
      if file:sub(1,2)==".\\" then file=file:sub(3) end
      if file ~= "." then
         table.insert(result, (file:gsub("\\", "/")))
      end
   end
   return result
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

   if filename then   
      return fs_execute("wget --quiet --continue --output-document ", filename, url)
   else
      return fs_execute("wget --quiet --continue ", url)
   end
end

--- Strip the path off a path+filename.
-- @param pathname string: A path+name, such as "/a/b/c".
-- @return string: The filename without its path, such as "c".
function base_name(pathname)
   assert(type(pathname) == "string")

   local base = pathname:match(".*[/\\]([^/\\]*)")
   return base or pathname
end

--- Strip the last extension of a filename.
-- Example: "foo.tar.gz" becomes "foo.tar".
-- If filename has no dots, returns it unchanged.
-- @param filename string: The file name to strip.
-- @return string: The stripped name.
local function strip_extension(filename)
   assert(type(filename) == "string")

   return (filename:gsub("%.[^.]+$", "")) or filename
end

--- Uncompress gzip file.
-- @param archive string: Filename of archive.
-- @return boolean : success status
local function gunzip(archive)
   local cmd = fs_execute("gunzip -h 1>NUL 2>NUL") and 'gunzip' or
               fs_execute("gzip   -h 1>NUL 2>NUL") and 'gzip -d'
   local ok = fs_execute(cmd, archive)
   return ok
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function unpack_archive(archive)
   assert(type(archive) == "string")
   
   local ok
   if archive:match("%.tar%.gz$") then
      ok = gunzip(archive)
      if ok then
         ok = fs_execute("tar -xf ", strip_extension(archive))
      end
   elseif archive:match("%.tgz$") then
      ok = gunzip(archive)
      if ok then
         ok = fs_execute("tar -xf ", strip_extension(archive)..".tar")
      end
   elseif archive:match("%.tar%.bz2$") then
      ok = fs_execute("bunzip2 ", archive)
      if ok then
         ok = fs_execute("tar -xf ", strip_extension(archive))
      end
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

   local base = fs_base_name(file)
   local wrapname = dest.."/"..base..".bat"
   local wrapper = io.open(wrapname, "w")
   if not wrapper then
      return nil, "Could not open "..wrapname.." for writing."
   end
   wrapper:write("@echo off\n")
   wrapper:write("setlocal\n")
   wrapper:write('set LUA_PATH='..package.path..";%LUA_PATH%\n")
   wrapper:write('set LUA_CPATH='..package.cpath..";%LUA_CPATH%\n")
   wrapper:write('"'..fs_make_path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)..'" -lluarocks.require "'..file..'" %*\n')
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
   local ok, err = fs_copy(filename, dest)
   if not ok then
      return nil, err
   end
   local exe_pattern = "%.[Ee][Xx][Ee]$"
   local base = fs_base_name(filename)
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
