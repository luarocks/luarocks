
--- fs operations implemented with third-party tools for Windows platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
--module("luarocks.fs.win32.tools", package.seeall)
local tools = {}

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

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

--- Obtain current directory.
-- Uses the module's internal directory stack.
-- @return string: the absolute pathname of the current directory.
function tools.current_dir()
   local current = cfg.cache_pwd
   if not current then
      local pipe = io.popen(fs.Q(vars.PWD))
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
function tools.execute_string(cmd)
   cmd = command_at(fs.current_dir(), cmd)
   local code = os.execute(cmd)
   if code == 0 or code == true then
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
function tools.change_dir(directory)
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
function tools.change_dir_to_root()
   table.insert(dir_stack, "/")
end

--- Change working directory to the previous in the directory stack.
function tools.pop_dir()
   local directory = table.remove(dir_stack)
   return directory ~= nil
end

--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name does not exist
-- too, they are created as well.
-- @param directory string: pathname of directory to create.
-- @return boolean: true on success, false on failure.
function tools.make_dir(directory)
   assert(directory)
   directory = dir.normalize(directory)
   fs.execute_quiet(fs.Q(vars.MKDIR).." -p ", directory)
   if not fs.is_dir(directory) then
      return false, "failed making directory "..directory
   end
   return true
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function tools.remove_dir_if_empty(directory)
   assert(directory)
   fs.execute_quiet(fs.Q(vars.RMDIR), directory)
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function tools.remove_dir_tree_if_empty(directory)
   assert(directory)
   fs.execute_quiet(fs.Q(vars.RMDIR), directory)
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function tools.copy(src, dest)
   assert(src and dest)
   if dest:match("[/\\]$") then dest = dest:sub(1, -2) end
   local ok = fs.execute(fs.Q(vars.CP), src, dest)
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
function tools.copy_contents(src, dest)
   assert(src and dest)
   if fs.execute_quiet(fs.Q(vars.CP), "-dR", src.."\\*.*", dest) then
      return true
   else
      return false, "Failed copying "..src.." to "..dest
   end
end

--- Delete a file or a directory and all its contents.
-- For safety, this only accepts absolute paths.
-- @param arg string: Pathname of source
-- @return nil
function tools.delete(arg)
   assert(arg)
   assert(arg:match("^[a-zA-Z]?:?[\\/]"))
   fs.execute_quiet("if exist "..fs.Q(arg.."\\").." ( RMDIR /S /Q "..fs.Q(arg).." ) else ( DEL /Q /F "..fs.Q(arg).." )")
end

--- Internal implementation function for fs.dir.
-- Yields a filename on each iteration.
-- @param at string: directory to list
-- @return nil
function tools.dir_iterator(at)
   local pipe = io.popen(command_at(at, fs.Q(vars.LS)))
   for file in pipe:lines() do
      if file ~= "." and file ~= ".." then
         coroutine.yield(file)
      end
   end
   pipe:close()
end

--- Recursively scan the contents of a directory.
-- @param at string or nil: directory to scan (will be the current
-- directory if none is given).
-- @return table: an array of strings with the filenames representing
-- the contents of a directory. Paths are returned with forward slashes.
function tools.find(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs.current_dir()
   end
   if not fs.is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen(command_at(at, fs.Q(vars.FIND).." 2> NUL"))
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
function tools.zip(zipfile, ...)
   return fs.execute_quiet(fs.Q(vars.SEVENZ).." -aoa a -tzip", zipfile, ...)
end

--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function tools.unzip(zipfile)
   assert(zipfile)
   return fs.execute_quiet(fs.Q(vars.SEVENZ).." -aoa x", zipfile)
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function tools.is_dir(file)
   assert(file)
   return fs.execute_quiet("if not exist " .. fs.Q(file.."\\").." invalidcommandname")
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a regular file, false otherwise.
function tools.is_file(file)
   assert(file)
   return fs.execute(fs.Q(vars.TEST).." -f", file)
end

--- Download a remote file.
-- @param url string: URL to be fetched.
-- @param filename string or nil: this function attempts to detect the
-- resulting local filename of the remote file as the basename of the URL;
-- if that is not correct (due to a redirection, for example), the local
-- filename can be given explicitly as this second argument.
-- @return (boolean, string): true and the filename on success,
-- false and the error message on failure.
function tools.use_downloader(url, filename, cache)
   assert(type(url) == "string")
   assert(type(filename) == "string" or not filename)

   filename = fs.absolute_name(filename or dir.base_name(url))

   local ok   
   if cfg.downloader == "wget" then
      local wget_cmd = fs.Q(vars.WGET).." "..vars.WGETNOCERTFLAG.." --no-cache --user-agent=\""..cfg.user_agent.." via wget\" --quiet "
      if cfg.connection_timeout and cfg.connection_timeout > 0 then
        wget_cmd = wget_cmd .. "--timeout="..tonumber(cfg.connection_timeout).." --tries=1 " 
      end
      if cache then
         -- --timestamping is incompatible with --output-document,
         -- but that's not a problem for our use cases.
         fs.change_dir(dir.dir_name(filename))
         ok = fs.execute_quiet(wget_cmd.." --timestamping ", url)
         fs.pop_dir()
      elseif filename then
         ok = fs.execute_quiet(wget_cmd.." --output-document ", filename, url)
      else
         ok = fs.execute_quiet(wget_cmd, url)
      end
   elseif cfg.downloader == "curl" then
      local curl_cmd = fs.Q(vars.CURL).." "..vars.CURLNOCERTFLAG.." -f -L --user-agent \""..cfg.user_agent.." via curl\" "
      if cfg.connection_timeout and cfg.connection_timeout > 0 then
        curl_cmd = curl_cmd .. "--connect-timeout "..tonumber(cfg.connection_timeout).." " 
      end
      ok = fs.execute_string(curl_cmd..fs.Q(url).." 2> NUL 1> "..fs.Q(filename))
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
  return fs.execute_quiet(fs.Q(vars.SEVENZ).." -aoa x", archive)
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function tools.unpack_archive(archive)
   assert(type(archive) == "string")

   local ok
   local sevenzx = fs.Q(vars.SEVENZ).." -aoa x"
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
   md5sum = fs.Q(vars.MD5SUM),
   openssl = fs.Q(vars.OPENSSL).." md5",
   md5 = fs.Q(vars.MD5),
}

--- Get the MD5 checksum for a file.
-- @param file string: The file to be computed.
-- @return string: The MD5 checksum or nil + message
function tools.get_md5(file)
   local cmd = md5_cmd[cfg.md5checker]
   if not cmd then return nil, "no MD5 checker command configured" end
   local pipe = io.popen(cmd.." "..fs.Q(fs.absolute_name(file)))
   local computed = pipe:read("*a")
   pipe:close()
   if computed then
      computed = computed:match("("..("%x"):rep(32)..")")
   end
   if computed then return computed end
   return nil, "Failed to compute MD5 hash for file "..tostring(fs.absolute_name(file))
end

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function tools.exists(file)
   assert(file)
   return fs.execute_quiet("if not exist " .. fs.Q(file) .. " invalidcommandname")
end

function tools.browser(url)
   return fs.execute(cfg.web_browser..' "Starting docs..." '..fs.Q(url))
end

return tools
