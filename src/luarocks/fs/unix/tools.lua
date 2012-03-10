
--- fs operations implemented with third-party tools for Unix platform abstractions.
module("luarocks.fs.unix.tools", package.seeall)

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

local dir_stack = {}

local vars = cfg.variables

--- Run the given command.
-- The command is executed in the current directory in the directory stack.
-- @param cmd string: No quoting/escaping is applied to the command.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function execute_string(cmd)
   local actual_cmd = "cd " .. fs.Q(fs.current_dir()) .. " && " .. cmd
   local code = os.execute(actual_cmd)
   if code == 0 or code == true then
      return true
   else
      return false
   end
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

--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name does not exist
-- too, they are created as well.
-- @param directory string: pathname of directory to create.
-- @return boolean: true on success, false on failure.
function make_dir(directory)
   assert(directory)
   return fs.execute(vars.MKDIR.." -p", directory)
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function remove_dir_if_empty(directory)
   assert(directory)
   fs.execute_string(vars.RMDIR.." "..fs.Q(directory).." 1> /dev/null 2> /dev/null")
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param directory string: pathname of directory to remove.
function remove_dir_tree_if_empty(directory)
   assert(directory)
   fs.execute_string(vars.RMDIR.." -p "..fs.Q(directory).." 1> /dev/null 2> /dev/null")
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @param perm string or nil: Permissions for destination file,
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function copy(src, dest, perm)
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
function copy_contents(src, dest)
   assert(src and dest)
   if fs.execute_string(vars.CP.." -pPR "..fs.Q(src).."/* "..fs.Q(dest).." 1> /dev/null 2>/dev/null") then
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
   return fs.execute_string(vars.RM.." -rf " .. fs.Q(arg) .. " 1> /dev/null 2>/dev/null")
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
   local pipe = io.popen("cd "..fs.Q(at).." && "..vars.LS)
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
      at = fs.current_dir()
   end
   if not fs.is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen("cd "..fs.Q(at).." && "..vars.FIND.." * 2>/dev/null") 
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
   return fs.execute(vars.ZIP.." -r", zipfile, ...)
end

--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function unzip(zipfile)
   assert(zipfile)
   return fs.execute(vars.UNZIP, zipfile)
end

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function exists(file)
   assert(file)
   return fs.execute(vars.TEST, "-r", file)
end

--- Test is file/directory is writable.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function is_writable(file)
   assert(file)
   return fs.execute(vars.TEST, "-w", file)
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function is_dir(file)
   assert(file)
   return fs.execute(vars.TEST, "-d", file)
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a regular file, false otherwise.
function is_file(file)
   assert(file)
   return fs.execute(vars.TEST, "-f", file)
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
      return fs.execute_string(vars.CURL.." -L --user-agent "..cfg.user_agent.." "..fs.Q(url).." 2> /dev/null 1> "..fs.Q(filename))
   end
end

function chmod(pathname, mode)
   if mode then 
      return fs.execute(vars.CHMOD, mode, pathname)
   else
      return false
   end
end

--- Apply a patch.
-- @param patchname string: The filename of the patch.
function apply_patch(patchname)
   return fs.execute(vars.PATCH.." -p1 -f -i ", patchname)
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
      -- ok = fs.execute("tar zxvpf ", archive)
         ok = fs.execute_string(vars.GUNZIP.." -c "..archive.."|"..vars.TAR.." -xf -")
   elseif archive:match("%.tar%.bz2$") then
      -- ok = fs.execute("tar jxvpf ", archive)
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
function get_md5(file)
   local cmd = md5_cmd[cfg.md5checker]
   if not cmd then return nil end
   local pipe = io.popen(cmd.." "..fs.absolute_name(file))
   local computed = pipe:read("*a")
   pipe:close()
   if not computed then return nil end
   return computed:match("("..("%x"):rep(32)..")")
end

function get_permissions(filename)
   local pipe = io.popen(vars.STAT.." "..vars.STATFLAG.." "..fs.Q(filename))
   local ret = pipe:read("*l")
   pipe:close()
   return ret
end
