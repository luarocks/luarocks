
--- fs operations implemented with third-party tools for Windows platform abstractions.
-- Download http://unxutils.sourceforge.net/ for Windows GNU utilities
-- used by this module.
local tools = {}

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

local vars = cfg.variables

--- Adds prefix to command to make it run from a directory.
-- @param directory string: Path to a directory.
-- @param cmd string: A command-line string.
-- @return string: The command-line with prefix.
function tools.command_at(directory, cmd)
   local drive = directory:match("^([A-Za-z]:)")
   cmd = "cd " .. fs.Q(directory) .. " & " .. cmd
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
   local pipe = io.popen(fs.command_at(at, fs.quiet_stderr(fs.Q(vars.FIND))))
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

return tools
