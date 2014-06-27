
--- fs operations implemented with third-party tools for Unix platform abstractions.
--module("luarocks.fs.unix.tools", package.seeall)
local tools = {}

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

local dir_stack = {}

local vars = cfg.variables

local function command_at(directory, cmd)
   return "cd " .. fs.Q(directory) .. " && " .. cmd
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
   local code, err = os.execute(command_at(fs.current_dir(), cmd))
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
   local ok, err = fs.execute(vars.MKDIR.." -p", directory)
   if not ok then
      err = "failed making directory "..directory
   end
   return ok, err
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function tools.remove_dir_if_empty(directory)
   assert(directory)
   fs.execute_quiet(vars.RMDIR, directory)
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function tools.remove_dir_tree_if_empty(directory)
   assert(directory)
   fs.execute_quiet(vars.RMDIR, "-p", directory)
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @param perm string or nil: Permissions for destination file,
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function tools.copy(src, dest, perm)
   assert(src and dest)
   if fs.execute(vars.CP, src, dest) then
      if perm then
         if fs.is_dir(dest) then
            dest = dir.path(dest, dir.base_name(src))
         end
         if fs.chmod(dest, perm) then
            return true
         else
            return false, "Failed setting permissions of "..dest
         end
      end
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
   if fs.execute_quiet(vars.CP.." -pPR "..fs.Q(src).."/* "..fs.Q(dest)) then
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
   assert(arg:sub(1,1) == "/")
   fs.execute_quiet(vars.RM, "-rf", arg)
end

--- Internal implementation function for fs.dir.
-- Yields a filename on each iteration.
-- @param at string: directory to list
-- @return nil
function tools.dir_iterator(at)
   local pipe = io.popen(command_at(at, vars.LS))
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
-- the contents of a directory.
function tools.find(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs.current_dir()
   end
   if not fs.is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen(command_at(at, vars.FIND.." * 2>/dev/null"))
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
function tools.zip(zipfile, ...)
   return fs.execute(vars.ZIP.." -r", zipfile, ...)
end

--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function tools.unzip(zipfile)
   assert(zipfile)
   return fs.execute_quiet(vars.UNZIP, zipfile)
end

--- Test is file/directory exists
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function tools.exists(file)
   assert(file)
   return fs.execute(vars.TEST, "-e", file)
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function tools.is_dir(file)
   assert(file)
   return fs.execute(vars.TEST, "-d", file)
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a regular file, false otherwise.
function tools.is_file(file)
   assert(file)
   return fs.execute(vars.TEST, "-f", file)
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
      local wget_cmd = fs.Q(vars.WGET).." --no-check-certificate --no-cache --user-agent='"..cfg.user_agent.." via wget' --quiet "
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
      local curl_cmd = fs.Q(vars.CURL).." -f -k -L --user-agent '"..cfg.user_agent.." via curl' "
      if cfg.connection_timeout and cfg.connection_timeout > 0 then
        curl_cmd = curl_cmd .. "--connect-timeout "..tonumber(cfg.connection_timeout).." " 
      end
      ok = fs.execute_string(curl_cmd..fs.Q(url).." 2> /dev/null 1> "..fs.Q(filename))
   end
   if ok then
      return true, filename
   else
      return false
   end
end

function tools.chmod(pathname, mode)
   if mode then 
      return fs.execute(vars.CHMOD, mode, pathname)
   else
      return false
   end
end

--- Apply a patch.
-- @param patchname string: The filename of the patch.
function tools.apply_patch(patchname)
   return fs.execute(vars.PATCH.." -p1 -f -i ", patchname)
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function tools.unpack_archive(archive)
   assert(type(archive) == "string")

   local ok
   if archive:match("%.tar%.gz$") or archive:match("%.tgz$") then
         ok = fs.execute_string(vars.GUNZIP.." -c "..archive.."|"..vars.TAR.." -xf -")
   elseif archive:match("%.tar%.bz2$") then
         ok = fs.execute_string(vars.BUNZIP2.." -c "..archive.."|tar -xf -")
   elseif archive:match("%.zip$") then
      ok = fs.execute(vars.UNZIP, archive)
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

function tools.get_permissions(filename)
   local pipe = io.popen(vars.STAT.." "..vars.STATFLAG.." "..fs.Q(filename))
   local ret = pipe:read("*l")
   pipe:close()
   return ret
end

function tools.browser(url)
   return fs.execute(cfg.web_browser, url)
end

return tools
