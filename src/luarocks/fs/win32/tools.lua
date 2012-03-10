
--- fs operations implemented with third-party tools for Windows platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
module("luarocks.fs.win32.tools", package.seeall)

local fs = require("luarocks.fs")
local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

local dir_stack = {}

local vars = cfg.variables

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

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function exists(file)
   assert(file)
   return fs.execute("if not exist " .. fs.Q(file) ..
                     " invalidcommandname 2>NUL 1>NUL")
end

--- Obtain current directory.
-- Uses the module's internal directory stack.
-- @return string: the absolute pathname of the current directory.
function current_dir()
   local pipe = io.popen(vars.PWD)
   local current = pipe:read("*l")
   pipe:close()
   for _, directory in ipairs(dir_stack) do
      current = fs.absolute_name(directory, current)
   end
   return current
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a regular file, false otherwise.
function is_file(file)
   assert(file)
   return fs.execute(vars.TEST.." -f", file)
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

--- Change the current directory.
-- Uses the module's internal directory stack. This does not have exact
-- semantics of chdir, as it does not handle errors the same way,
-- but works well for our purposes for now.
-- @param directory string: The directory to switch to.
function change_dir(directory)
   assert(type(directory) == "string")
   table.insert(dir_stack, directory)
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

--- Run the given command.
-- The command is executed in the current directory in the directory stack.
-- @param cmd string: No quoting/escaping is applied to the command.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function execute_string(cmd)
   local code = os.execute(command_at(fs.current_dir(), cmd))
   if code == 0 or code == true then
      return true
   else
      return false
   end
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a regular file, false otherwise.
function is_dir(file)
   assert(file)
   return fs.execute(vars.TEST.." -d " .. fs.Q(file) .. " 2>NUL 1>NUL")
end

--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name does not exist
-- too, they are created as well.
-- @param directory string: pathname of directory to create.
-- @return boolean: true on success, false on failure.
function make_dir(directory)
   assert(directory)
   fs.execute(vars.MKDIR.." "..fs.Q(directory).." 1> NUL 2> NUL")
   return 1
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function remove_dir_if_empty(directory)
   assert(directory)
   fs.execute_string(vars.RMDIR.." "..fs.Q(directory).." 1> NUL 2> NUL")
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function remove_dir_tree_if_empty(directory)
   assert(directory)
   fs.execute_string(vars.RMDIR.." "..fs.Q(directory).." 1> NUL 2> NUL")
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy(src, dest)
   assert(src and dest)
   if dest:match("[/\\]$") then dest = dest:sub(1, -2) end
   if fs.execute(vars.CP, src, dest) then
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
   if fs.execute_string(vars.CP.." -a "..src.."\\*.* "..fs.Q(dest).." 1> NUL 2> NUL") then
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
   fs.execute(vars.CHMOD.." a+rw -R ", arg)
   return fs.execute_string(vars.RM.." -rf " .. fs.Q(arg) .. " 1> NUL 2> NUL")
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

   if cfg.downloader == "wget" then
      local wget_cmd = vars.WGET.." --no-check-certificate --no-cache --user-agent="..cfg.user_agent.." --quiet --continue "
      if filename then
         return fs.execute(wget_cmd.." --output-document ", filename, url)
      else
         return fs.execute(wget_cmd, url)
      end
   elseif cfg.downloader == "curl" then
      filename = filename or dir.base_name(url)
      return fs.execute_string(vars.CURL.." -L --user-agent "..cfg.user_agent.." "..fs.Q(url).." 2> NUL 1> "..fs.Q(filename))
   end
end


--- Compress files in a .zip archive.
-- @param zipfile string: pathname of .zip archive to be created.
-- @param ... Filenames to be stored in the archive are given as
-- additional arguments.
-- @return boolean: true on success, false on failure.
function zip(zipfile, ...)
   return fs.execute(vars.SEVENZ.." a -tzip", zipfile, ...)
end

--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function unzip(zipfile)
   assert(zipfile)
   return fs.execute(vars.SEVENZ.." x", zipfile)
end

--- Uncompress gzip file.
-- @param archive string: Filename of archive.
-- @return boolean : success status
local function gunzip(archive)
  return fs.execute(vars.SEVENZ.." x", archive)
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function unpack_archive(archive)
   assert(type(archive) == "string")

   local ok
   local sevenzx = vars.SEVENZ.." x"
   if archive:match("%.tar%.gz$") then
      ok = gunzip(archive)
      if ok then
         ok = fs.execute(sevenzx, strip_extension(archive))
      end
   elseif archive:match("%.tgz$") then
      ok = gunzip(archive)
      if ok then
         ok = fs.execute(sevenzx, strip_extension(archive)..".tar")
      end
   elseif archive:match("%.tar%.bz2$") then
      ok = fs.execute(sevenzx, archive)
      if ok then
         ok = fs.execute(sevenzx, strip_extension(archive))
      end
   elseif archive:match("%.zip$") then
      ok = fs.execute(sevenzx, archive)
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
