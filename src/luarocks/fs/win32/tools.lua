
--- fs operations implemented with third-party tools for Windows platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
local tools = {}

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.core.cfg")

local vars = setmetatable({}, { __index = function(_,k) return cfg.variables[k] end })

--- Adds prefix to command to make it run from a directory.
-- @param directory string: Path to a directory.
-- @param cmd string: A command-line string.
-- @param exit_on_error bool: Exits immediately if entering the directory failed.
-- @return string: The command-line with prefix.
function tools.command_at(directory, cmd, exit_on_error)
   local drive = directory:match("^([A-Za-z]:)")
   local op = " & "
   if exit_on_error then
      op = " && "
   end
   local cmd = "cd " .. fs.Q(directory) .. op .. cmd
   if drive then
      cmd = drive .. " & " .. cmd
   end
   return cmd
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
   if not fs.is_dir(src) then
      return false, src .. " is not a directory"
   end
   if fs.make_dir(dest) and fs.execute_quiet(fs.Q(vars.CP), "-dR", src.."\\*.*", dest) then
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
   fs.execute_quiet("if exist "..fs.Q(arg.."\\*").." ( RMDIR /S /Q "..fs.Q(arg).." ) else ( DEL /Q /F "..fs.Q(arg).." )")
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
   local pipe = io.popen(fs.command_at(at, fs.quiet_stderr(fs.Q(vars.FIND)), true))
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

--- Helper function for fs.set_permissions
-- @return table: an array of all system users
local function get_system_users()
   result = {}
   local fd = assert(io.popen("wmic UserAccount get name"))
   for user in fd:lines() do
      user = user:gsub("%s+$", "")
      if user ~= "" and user ~= "Name" and user ~= "Administrator" then
         table.insert(result, user)
      end
   end
   return result
end

--- Set permissions for file or directory
-- @param filename string: filename whose permissions are to be modified
-- @param mode string ("read" or "exec"): permission to set
-- @param scope string ("user" or "all"): the user(s) to whom the permission applies
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message
function tools.set_permissions(filename, mode, scope)
   assert(filename and mode and scope)

   if scope == "user" then
      local perms
      if mode == "read" then
         perms = "(R,W,M)"
      elseif mode == "exec" then
         perms = "(F)"
      end

      local ok
      -- Take ownership of the given file
      ok = fs.execute_quiet("takeown /f " .. fs.Q(filename))
      if not ok then
         return false, "Could not take ownership of the given file"
      end
      -- Grant the current user the proper rights
      ok = fs.execute_quiet(fs.Q(vars.ICACLS) .. " " .. fs.Q(filename) .. " /inheritance:d /grant:r %USERNAME%:" .. perms)
      if not ok then
         return false, "Failed setting permission " .. mode .. " for " .. scope
      end
      -- Finally, remove all the other users from the ACL in order to deny them access to the file
      for _, user in pairs(get_system_users()) do
         if user ~= who then
            local ok = fs.execute_quiet(fs.Q(vars.ICACLS) .. " " .. fs.Q(filename) .. " /remove " .. fs.Q(user))
            if not ok then
               return false, "Failed setting permission " .. mode .. " for " .. scope
            end
         end
      end
   elseif scope == "all" then
      local my_perms, others_perms
      if mode == "read" then
         my_perms = "(R,W,M)"
         others_perms = "(R)"
      elseif mode == "exec" then
         my_perms = "(F)"
         others_perms = "(RX)"
      end

      local ok
      -- Grant permissions available to all users
      ok = fs.execute_quiet(fs.Q(vars.ICACLS) .. " " .. fs.Q(filename) .. " /inheritance:d /grant:r Everyone:" .. others_perms)
      if not ok then
         return false, "Failed setting permission " .. mode .. " for " .. scope
      end
      -- Grant permissions available only to the current user
      ok = fs.execute_quiet(fs.Q(vars.ICACLS) .. " " .. fs.Q(filename) .. " /inheritance:d /grant %USERNAME%:" .. my_perms)
      if not ok then
         return false, "Failed setting permission " .. mode .. " for " .. scope
      end
   end

   return true
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
      return false, "Couldn't extract archive "..archive..": unrecognized filename extension"
   end
   if not ok then
      return false, "Failed extracting "..archive
   end
   return true
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

-- Set access and modification times for a file.
-- @param filename File to set access and modification times for.
-- @param time may be a string or number containing the format returned
-- by os.time, or a table ready to be processed via os.time; if
-- nil, current time is assumed.
function tools.set_time(filename, time)
   return true -- FIXME
end

return tools
