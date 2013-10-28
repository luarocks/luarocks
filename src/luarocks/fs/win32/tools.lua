
--- fs operations implemented with third-party tools for Windows platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
module("luarocks.fs.win32.tools", package.seeall)

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

local dir_stack = {}

local vars = cfg.variables

local function pack(...)
   return { n = select("#", ...), ... }
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

local function command_at(directory, cmd)
   local drive = directory:match("^([A-Za-z]:)")
   cmd = "cd " .. fs.Q(directory) .. " & " .. cmd
   if drive then
      cmd = drive .. " & " .. cmd
   end
   return cmd
end

--- Obtain current directory.
-- Uses the module's internal directory stack.
-- @return string: the absolute pathname of the current directory.
function current_dir()
   local current = cfg.cache_pwd
   if not current then
      local pipe = io.popen(vars.PWD)
      current = pipe:read("*l")
      pipe:close()
      cfg.cache_pwd = current
   end
   for _, directory in ipairs(dir_stack) do
      current = fs.absolute_name(directory, current)
   end
   return current
end

--- Run the given command.
-- The command is executed in the current directory in the directory stack.
-- @param cmd string: No quoting/escaping is applied to the command.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function execute_string(cmd)
   cmd = command_at(fs.current_dir(), cmd)
   if cfg.verbose then print("Executing: "..tostring(cmd)) end
   local code = pack(os.execute(cmd))
   if cfg.verbose then
      print("Results: "..tostring(code.n))
      for i = 1,code.n do
         print("  "..tostring(i).." ("..type(code[i]).."): "..tostring(code[i]))
      end
      print()
   end
   if code[1] == 0 or code[1] == true then
      return true
   else
      return false
   end
end

--- Change the current directory.
-- Uses the module's internal directory stack. This does not have exact
-- semantics of chdir, as it does not handle errors the same way,
-- but works well for our purposes for now.
-- @param directory string: The directory to switch to.
-- @return boolean or (nil, string): true if successful, (nil, error message) if failed.
function change_dir(directory)
   assert(type(directory) == "string")
   if fs.is_dir(directory) then
      table.insert(dir_stack, directory)
      return true
   end
   return nil, "directory not found: "..directory
end

--- Change directory to root.
-- Allows leaving a directory (e.g. for deleting it) in
-- a crossplatform way.
function change_dir_to_root()
   table.insert(dir_stack, "/")
end

--- Change working directory to the previous in the directory stack.
function pop_dir()
   local directory = table.remove(dir_stack)
   return directory ~= nil
end

--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name does not exist
-- too, they are created as well.
-- @param directory string: pathname of directory to create.
-- @return boolean: true on success, false on failure.
function make_dir(directory)
   assert(directory)
   directory = dir.normalize(directory)
   fs.execute_quiet(vars.MKDIR.." -p ", directory)
   if not fs.is_dir(directory) then
      return false, "failed making directory "..directory
   end
   return true
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function remove_dir_if_empty(directory)
   assert(directory)
   fs.execute_quiet(vars.RMDIR, directory)
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function remove_dir_tree_if_empty(directory)
   assert(directory)
   fs.execute_quiet(vars.RMDIR, directory)
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy(src, dest)
   assert(src and dest)
   if dest:match("[/\\]$") then dest = dest:sub(1, -2) end
   local ok = fs.execute(vars.CP, src, dest)
   if ok then
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
   if fs.execute_quiet(vars.CP.." -dR "..src.."\\*.* "..fs.Q(dest)) then
      return true
   else
      return false, "Failed copying "..src.." to "..dest
   end
end

--- Delete a file or a directory and all its contents.
-- For safety, this only accepts absolute paths.
-- @param arg string: Pathname of source
-- @return nil
function delete(arg)
   assert(arg)
   assert(arg:match("^[a-zA-Z]?:?[\\/]"))
   fs.execute_quiet("if exist "..fs.Q(arg.."\\").." ( RMDIR /S /Q "..fs.Q(arg).." ) else ( DEL /Q /F "..fs.Q(arg).." )")
end

--- List the contents of a directory.
-- @param at string or nil: directory to list (will be the current
-- directory if none is given).
-- @return table: an array of strings with the filenames representing
-- the contents of a directory.
function list_dir(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs.current_dir()
   end
   if not fs.is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen(command_at(at, vars.LS))
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
      at = fs.current_dir()
   end
   if not fs.is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen(command_at(at, vars.FIND.." 2> NUL"))
   for file in pipe:lines() do
      -- Windows find is a bit different
      local first_two = file:sub(1,2)
      if first_two == ".\\" or first_two == "./" then file=file:sub(3) end
      if file ~= "." then
         table.insert(result, (file:gsub("\\", "/")))
      end
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
   return fs.execute_quiet(vars.SEVENZ.." -aoa a -tzip", zipfile, ...)
end

--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function unzip(zipfile)
   assert(zipfile)
   return fs.execute_quiet(vars.SEVENZ.." -aoa x", zipfile)
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function is_dir(file)
   assert(file)
   return fs.execute_quiet("if not exist " .. fs.Q(file.."\\").." invalidcommandname")
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a regular file, false otherwise.
function is_file(file)
   assert(file)
   return fs.execute(vars.TEST.." -f", file)
end

--- Download a remote file.
-- @param url string: URL to be fetched.
-- @param filename string or nil: this function attempts to detect the
-- resulting local filename of the remote file as the basename of the URL;
-- if that is not correct (due to a redirection, for example), the local
-- filename can be given explicitly as this second argument.
-- @return (boolean, string): true and the filename on success,
-- false and the error message on failure.
function download(url, filename, cache)
   assert(type(url) == "string")
   assert(type(filename) == "string" or not filename)

   filename = fs.absolute_name(filename or dir.base_name(url))

   local ok   
   if cfg.downloader == "wget" then
      local wget_cmd = vars.WGET.." --no-check-certificate --no-cache --user-agent=\""..cfg.user_agent.." via wget\" --quiet "
      if cache then
         -- --timestamping is incompatible with --output-document,
         -- but that's not a problem for our use cases.
         fs.change_dir(dir.dir_name(filename))
         ok = fs.execute(wget_cmd.." --timestamping "..fs.Q(url).." 2> NUL 1> NUL")
         fs.pop_dir()
      elseif filename then
         ok = fs.execute(wget_cmd.." --output-document "..fs.Q(filename).." "..fs.Q(url).." 2> NUL 1> NUL")
      else
         ok = fs.execute(wget_cmd..fs.Q(url).." 2> NUL 1> NUL")
      end
   elseif cfg.downloader == "curl" then
      ok = fs.execute_string(vars.CURL.." -L --user-agent \""..cfg.user_agent.." via curl\" "..fs.Q(url).." 2> NUL 1> "..fs.Q(filename))
   end
   if ok then
      return true, filename
   else
      return false
   end
end

--- Uncompress gzip file.
-- @param archive string: Filename of archive.
-- @return boolean : success status
local function gunzip(archive)
  return fs.execute_quiet(vars.SEVENZ.." -aoa x", archive)
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function unpack_archive(archive)
   assert(type(archive) == "string")

   local ok
   local sevenzx = vars.SEVENZ.." -aoa x"
   if archive:match("%.tar%.gz$") then
      ok = gunzip(archive)
      if ok then
         ok = fs.execute_quiet(sevenzx, strip_extension(archive))
      end
   elseif archive:match("%.tgz$") then
      ok = gunzip(archive)
      if ok then
         ok = fs.execute_quiet(sevenzx, strip_extension(archive)..".tar")
      end
   elseif archive:match("%.tar%.bz2$") then
      ok = fs.execute_quiet(sevenzx, archive)
      if ok then
         ok = fs.execute_quiet(sevenzx, strip_extension(archive))
      end
   elseif archive:match("%.zip$") then
      ok = fs.execute_quiet(sevenzx, archive)
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

local md5_cmd = {
   md5sum = vars.MD5SUM,
   openssl = vars.OPENSSL.." md5",
   md5 = vars.MD5,
}

--- Get the MD5 checksum for a file.
-- @param file string: The file to be computed.
-- @return string: The MD5 checksum
function get_md5(file)
   local cmd = md5_cmd[cfg.md5checker]
   if not cmd then return nil end
   local pipe = io.popen(cmd.." "..fs.absolute_name(file))
   local computed = pipe:read("*a")
   pipe:close()
   if not computed then return nil end
   return computed:match("("..("%x"):rep(32)..")")
end

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function exists(file)
   assert(file)
   return fs.execute_quiet("if not exist " .. fs.Q(file) .. " invalidcommandname")
end
