
--- Native Lua implementation of filesystem and platform abstractions,
-- using LuaFileSystem, LZLib, MD5 and LuaCurl.
-- module("luarocks.fs.lua")
local fs_lua = {}

local fs = require("luarocks.fs")

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local path = require("luarocks.path")

local socket_ok, zip_ok, unzip_ok, lfs_ok, md5_ok, posix_ok, _
local http, ftp, lrzip, luazip, lfs, md5, posix

if cfg.fs_use_modules then
   socket_ok, http = pcall(require, "socket.http")
   _, ftp = pcall(require, "socket.ftp")
   zip_ok, lrzip = pcall(require, "luarocks.tools.zip")
   unzip_ok, luazip = pcall(require, "zip"); _G.zip = nil
   lfs_ok, lfs = pcall(require, "lfs")
   md5_ok, md5 = pcall(require, "md5")
   posix_ok, posix = pcall(require, "posix")
end

local patch = require("luarocks.tools.patch")

local dir_stack = {}

local dir_separator = "/"

--- Test is file/dir is writable.
-- Warning: testing if a file/dir is writable does not guarantee
-- that it will remain writable and therefore it is no replacement
-- for checking the result of subsequent operations.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function fs_lua.is_writable(file)
   assert(file)
   file = dir.normalize(file)
   local result
   if fs.is_dir(file) then
      local file2 = dir.path(file, '.tmpluarockstestwritable')
      local fh = io.open(file2, 'wb')
      result = fh ~= nil
      if fh then fh:close() end
      os.remove(file2)
   else
      local fh = io.open(file, 'r+b')
      result = fh ~= nil
      if fh then fh:close() end
   end
   return result
end

local function quote_args(command, ...)
   local out = { command }
   for _, arg in ipairs({...}) do
      assert(type(arg) == "string")
      out[#out+1] = fs.Q(arg)
   end
   return table.concat(out, " ")
end

--- Run the given command, quoting its arguments.
-- The command is executed in the current directory in the dir stack.
-- @param command string: The command to be executed. No quoting/escaping
-- is applied.
-- @param ... Strings containing additional arguments, which are quoted.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function fs_lua.execute(command, ...)
   assert(type(command) == "string")
   return fs.execute_string(quote_args(command, ...))
end

--- Run the given command, quoting its arguments, silencing its output.
-- The command is executed in the current directory in the dir stack.
-- Silencing is omitted if 'verbose' mode is enabled.
-- @param command string: The command to be executed. No quoting/escaping
-- is applied.
-- @param ... Strings containing additional arguments, which will be quoted.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function fs_lua.execute_quiet(command, ...)
   assert(type(command) == "string")
   if cfg.verbose then -- omit silencing output
      return fs.execute_string(quote_args(command, ...))
   else
      return fs.execute_string(fs.quiet(quote_args(command, ...)))
   end
end

--- Checks if the given tool is available.
-- The tool is executed using a flag, usually just to ask its version.
-- @param tool_cmd string: The command to be used to check the tool's presence (e.g. hg in case of Mercurial)
-- @param tool_name string: The actual name of the tool (e.g. Mercurial)
-- @param arg string: The flag to pass to the tool. '--version' by default.
function fs_lua.is_tool_available(tool_cmd, tool_name, arg)
   assert(type(tool_cmd) == "string")
   assert(type(tool_name) == "string")

   arg = arg or "--version"
   assert(type(arg) == "string")

   if not fs.execute_quiet(fs.Q(tool_cmd), arg) then
      local msg = "'%s' program not found. Make sure %s is installed and is available in your PATH " ..
                  "(or you may want to edit the 'variables.%s' value in file '%s')"
      return nil, msg:format(tool_cmd, tool_name, tool_name:upper(), cfg.which_config().nearest)
   else
      return true
   end
end

--- Check the MD5 checksum for a file.
-- @param file string: The file to be checked.
-- @param md5sum string: The string with the expected MD5 checksum.
-- @return boolean: true if the MD5 checksum for 'file' equals 'md5sum', false + msg if not
-- or if it could not perform the check for any reason.
function fs_lua.check_md5(file, md5sum)
   file = dir.normalize(file)
   local computed, msg = fs.get_md5(file)
   if not computed then
      return false, msg
   end
   if computed:match("^"..md5sum) then
      return true
   else
      return false, "Mismatch MD5 hash for file "..file
   end
end

--- List the contents of a directory.
-- @param at string or nil: directory to list (will be the current
-- directory if none is given).
-- @return table: an array of strings with the filenames representing
-- the contents of a directory.
function fs_lua.list_dir(at)
   local result = {}
   for file in fs.dir(at) do
      result[#result+1] = file
   end
   return result
end

--- Iterate over the contents of a directory.
-- @param at string or nil: directory to list (will be the current
-- directory if none is given).
-- @return function: an iterator function suitable for use with
-- the for statement.
function fs_lua.dir(at)
   if not at then
      at = fs.current_dir()
   end
   at = dir.normalize(at)
   if not fs.is_dir(at) then
      return function() end
   end
   return coroutine.wrap(function() fs.dir_iterator(at) end)
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
function fs_lua.execute_string(cmd)
   local code = os.execute(cmd)
   return (code == 0 or code == true)
end

--- Obtain current directory.
-- Uses the module's internal dir stack.
-- @return string: the absolute pathname of the current directory.
function fs_lua.current_dir()
   return lfs.currentdir()
end

--- Change the current directory.
-- Uses the module's internal dir stack. This does not have exact
-- semantics of chdir, as it does not handle errors the same way,
-- but works well for our purposes for now.
-- @param d string: The directory to switch to.
function fs_lua.change_dir(d)
   table.insert(dir_stack, lfs.currentdir())
   d = dir.normalize(d)
   return lfs.chdir(d)
end

--- Change directory to root.
-- Allows leaving a directory (e.g. for deleting it) in
-- a crossplatform way.
function fs_lua.change_dir_to_root()
   local current = lfs.currentdir()
   if not current or current == "" then
      return false
   end
   table.insert(dir_stack, current)
   lfs.chdir("/") -- works on Windows too
   return true
end

--- Change working directory to the previous in the dir stack.
-- @return true if a pop ocurred, false if the stack was empty.
function fs_lua.pop_dir()
   local d = table.remove(dir_stack)
   if d then
      lfs.chdir(d)
      return true
   else
      return false
   end
end

--- Create a directory if it does not already exist.
-- If any of the higher levels in the path name do not exist
-- too, they are created as well.
-- @param directory string: pathname of directory to create.
-- @return boolean or (boolean, string): true on success or (false, error message) on failure.
function fs_lua.make_dir(directory)
   assert(type(directory) == "string")
   directory = dir.normalize(directory)
   local path = nil
   if directory:sub(2, 2) == ":" then
     path = directory:sub(1, 2)
     directory = directory:sub(4)
   else
     if directory:match("^/") then
        path = ""
     end
   end
   for d in directory:gmatch("([^"..dir.separator.."]+)"..dir.separator.."*") do
      path = path and path .. dir.separator .. d or d
      local mode = lfs.attributes(path, "mode")
      if not mode then
         local ok, err = lfs.mkdir(path)
         if not ok then
            return false, err
         end
         ok, err = fs.chmod(path, cfg.perm_exec)
         if not ok then
            return false, err
         end
      elseif mode ~= "directory" then
         return false, path.." is not a directory"
      end
   end
   return true
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param d string: pathname of directory to remove.
function fs_lua.remove_dir_if_empty(d)
   assert(d)
   d = dir.normalize(d)
   lfs.rmdir(d)
end

--- Remove a directory if it is empty.
-- Does not return errors (for example, if directory is not empty or
-- if already does not exist)
-- @param d string: pathname of directory to remove.
function fs_lua.remove_dir_tree_if_empty(d)
   assert(d)
   d = dir.normalize(d)
   for i=1,10 do
      lfs.rmdir(d)
      d = dir.dir_name(d)
   end
end

--- Copy a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @param perms string or nil: Permissions for destination file,
-- or nil to use the source filename permissions
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function fs_lua.copy(src, dest, perms)
   assert(src and dest)
   src = dir.normalize(src)
   dest = dir.normalize(dest)
   local destmode = lfs.attributes(dest, "mode")
   if destmode == "directory" then
      dest = dir.path(dest, dir.base_name(src))
   end
   if not perms then perms = fs.attributes(src, "permissions") end
   local src_h, err = io.open(src, "rb")
   if not src_h then return nil, err end
   local dest_h, err = io.open(dest, "w+b")
   if not dest_h then src_h:close() return nil, err end
   while true do
      local block = src_h:read(8192)
      if not block then break end
      dest_h:write(block)
   end
   src_h:close()
   dest_h:close()
   fs.chmod(dest, perms)
   return true
end

--- Implementation function for recursive copy of directory contents.
-- Assumes paths are normalized.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @param perms string or nil: Optional permissions.
-- If not given, permissions of the source are copied over to the destination.
-- @return boolean or (boolean, string): true on success, false on failure
local function recursive_copy(src, dest, perms)
   local srcmode = lfs.attributes(src, "mode")

   if srcmode == "file" then
      local ok = fs.copy(src, dest, perms)
      if not ok then return false end
   elseif srcmode == "directory" then
      local subdir = dir.path(dest, dir.base_name(src))
      local ok, err = fs.make_dir(subdir)
      if not ok then return nil, err end
      for file in lfs.dir(src) do
         if file ~= "." and file ~= ".." then
            local ok = recursive_copy(dir.path(src, file), subdir, perms)
            if not ok then return false end
         end
      end
   end
   return true
end

--- Recursively copy the contents of a directory.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @param perms string or nil: Optional permissions. 
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function fs_lua.copy_contents(src, dest, perms)
   assert(src and dest)
   src = dir.normalize(src)
   dest = dir.normalize(dest)
   assert(lfs.attributes(src, "mode") == "directory")

   for file in lfs.dir(src) do
      if file ~= "." and file ~= ".." then
         local ok = recursive_copy(dir.path(src, file), dest, perms)
         if not ok then
            return false, "Failed copying "..src.." to "..dest
         end
      end
   end
   return true
end

--- Implementation function for recursive removal of directories.
-- Assumes paths are normalized.
-- @param name string: Pathname of file
-- @return boolean or (boolean, string): true on success,
-- or nil and an error message on failure.
local function recursive_delete(name)
   local ok = os.remove(name)
   if ok then return true end
   local pok, ok, err = pcall(function()
      for file in lfs.dir(name) do
         if file ~= "." and file ~= ".." then
            local ok, err = recursive_delete(dir.path(name, file))
            if not ok then return nil, err end
         end
      end
      local ok, err = lfs.rmdir(name)
      return ok, (not ok) and err
   end)
   if pok then
      return ok, err
   else
      return pok, ok
   end
end

--- Delete a file or a directory and all its contents.
-- @param name string: Pathname of source
-- @return nil
function fs_lua.delete(name)
   name = dir.normalize(name)
   recursive_delete(name)
end

--- Internal implementation function for fs.dir.
-- Yields a filename on each iteration.
-- @param at string: directory to list
-- @return nil
function fs_lua.dir_iterator(at)
   for file in lfs.dir(at) do
      if file ~= "." and file ~= ".." then
         coroutine.yield(file)
      end
   end
end

--- Implementation function for recursive find.
-- Assumes paths are normalized.
-- @param cwd string: Current working directory in recursion.
-- @param prefix string: Auxiliary prefix string to form pathname.
-- @param result table: Array of strings where results are collected.
local function recursive_find(cwd, prefix, result)
   for file in lfs.dir(cwd) do
      if file ~= "." and file ~= ".." then
         local item = prefix .. file
         table.insert(result, item)
         local pathname = dir.path(cwd, file)
         if lfs.attributes(pathname, "mode") == "directory" then
            recursive_find(pathname, item..dir_separator, result)
         end
      end
   end
end

--- Recursively scan the contents of a directory.
-- @param at string or nil: directory to scan (will be the current
-- directory if none is given).
-- @return table: an array of strings with the filenames representing
-- the contents of a directory.
function fs_lua.find(at)
   assert(type(at) == "string" or not at)
   if not at then
      at = fs.current_dir()
   end
   at = dir.normalize(at)
   if not fs.is_dir(at) then
      return {}
   end
   local result = {}
   recursive_find(at, "", result)
   return result
end

--- Test for existance of a file.
-- @param file string: filename to test
-- @return boolean: true if file exists, false otherwise.
function fs_lua.exists(file)
   assert(file)
   file = dir.normalize(file)
   return type(lfs.attributes(file)) == "table"
end

--- Test is pathname is a directory.
-- @param file string: pathname to test
-- @return boolean: true if it is a directory, false otherwise.
function fs_lua.is_dir(file)
   assert(file)
   file = dir.normalize(file)
   return lfs.attributes(file, "mode") == "directory"
end

--- Test is pathname is a regular file.
-- @param file string: pathname to test
-- @return boolean: true if it is a file, false otherwise.
function fs_lua.is_file(file)
   assert(file)
   file = dir.normalize(file)
   return lfs.attributes(file, "mode") == "file"
end

function fs_lua.set_time(file, time)
   file = dir.normalize(file)
   return lfs.touch(file, time)
end

end

---------------------------------------------------------------------
-- LuaZip functions
---------------------------------------------------------------------

if zip_ok then

function fs_lua.zip(zipfile, ...)
   return lrzip.zip(zipfile, ...)
end

end

if unzip_ok then
--- Uncompress files from a .zip archive.
-- @param zipfile string: pathname of .zip archive to be extracted.
-- @return boolean: true on success, false on failure.
function fs_lua.unzip(zipfile)
   local zipfile, err = luazip.open(zipfile)
   if not zipfile then return nil, err end
   local files = zipfile:files()
   local file = files()
   repeat
      if file.filename:sub(#file.filename) == "/" then
         local ok, err = fs.make_dir(dir.path(fs.current_dir(), file.filename))
         if not ok then return nil, err end
      else
         local base = dir.dir_name(file.filename)
         if base ~= "" then
            base = dir.path(fs.current_dir(), base)
            if not fs.is_dir(base) then
               local ok, err = fs.make_dir(base)
               if not ok then return nil, err end
            end
         end
         local rf, err = zipfile:open(file.filename)
         if not rf then zipfile:close(); return nil, err end
         local contents = rf:read("*a")
         rf:close()
         local wf, err = io.open(dir.path(fs.current_dir(), file.filename), "wb")
         if not wf then zipfile:close(); return nil, err end
         wf:write(contents)
         wf:close()
      end
      file = files()
   until not file
   zipfile:close()
   return true
end

end

---------------------------------------------------------------------
-- LuaSocket functions
---------------------------------------------------------------------

if socket_ok then

local ltn12 = require("ltn12")
local luasec_ok, https = pcall(require, "ssl.https")

local redirect_protocols = {
   http = http,
   https = luasec_ok and https,
}

local function request(url, method, http, loop_control)
   local result = {}
   
   local proxy = cfg.http_proxy
   if type(proxy) ~= "string" then proxy = nil end
   -- LuaSocket's http.request crashes when given URLs missing the scheme part.
   if proxy and not proxy:find("://") then
      proxy = "http://" .. proxy
   end
   
   if cfg.show_downloads then
      io.write(method.." "..url.." ...\n")
   end
   local dots = 0
   if cfg.connection_timeout and cfg.connection_timeout > 0 then
      http.TIMEOUT = cfg.connection_timeout
   end
   local res, status, headers, err = http.request {
      url = url,
      proxy = proxy,
      method = method,
      redirect = false,
      sink = ltn12.sink.table(result),
      step = cfg.show_downloads and function(...)
         io.write(".")
         io.flush()
         dots = dots + 1
         if dots == 70 then
            io.write("\n")
            dots = 0
         end
         return ltn12.pump.step(...)
      end,
      headers = {
         ["user-agent"] = cfg.user_agent.." via LuaSocket"
      },
   }
   if cfg.show_downloads then
      io.write("\n")
   end
   if not res then
      return nil, status
   elseif status == 301 or status == 302 then
      local location = headers.location
      if location then
         local protocol, rest = dir.split_url(location)
         if redirect_protocols[protocol] then
            if not loop_control then
               loop_control = {}
            elseif loop_control[location] then
               return nil, "Redirection loop -- broken URL?"
            end
            loop_control[url] = true
            return request(location, method, redirect_protocols[protocol], loop_control)
         else
            return nil, "URL redirected to unsupported protocol - install luasec to get HTTPS support.", "https"
         end
      end
      return nil, err
   elseif status ~= 200 then
      return nil, err
   else
      return result, status, headers, err
   end
end

local function http_request(url, http, cached)
   if cached then
      local tsfd = io.open(cached..".timestamp", "r")
      if tsfd then
         local timestamp = tsfd:read("*a")
         tsfd:close()
         local result, status, headers, err = request(url, "HEAD", http)
         if status == 200 and headers["last-modified"] == timestamp then
            return true
         end
         if not result then
            return nil, status, headers
         end
      end
   end
   local result, status, headers, err = request(url, "GET", http)
   if result then
      if cached and headers["last-modified"] then
         local tsfd = io.open(cached..".timestamp", "w")
         if tsfd then
            tsfd:write(headers["last-modified"])
            tsfd:close()
         end
      end
      return table.concat(result)
   else
      return nil, status, headers
   end
end

local downloader_warning = false

--- Download a remote file.
-- @param url string: URL to be fetched.
-- @param filename string or nil: this function attempts to detect the
-- resulting local filename of the remote file as the basename of the URL;
-- if that is not correct (due to a redirection, for example), the local
-- filename can be given explicitly as this second argument.
-- @return (boolean, string): true and the filename on success,
-- false and the error message on failure.
function fs_lua.download(url, filename, cache)
   assert(type(url) == "string")
   assert(type(filename) == "string" or not filename)

   filename = fs.absolute_name(filename or dir.base_name(url))

   -- delegate to the configured downloader so we don't have to deal with whitelists
   if cfg.no_proxy then
      return fs.use_downloader(url, filename, cache)
   end
   
   local content, err, https_err
   if util.starts_with(url, "http:") then
      content, err, https_err = http_request(url, http, cache and filename)
   elseif util.starts_with(url, "ftp:") then
      content, err = ftp.get(url)
   elseif util.starts_with(url, "https:") then
      -- skip LuaSec when proxy is enabled since it is not supported
      if luasec_ok and not cfg.https_proxy then
         content, err = http_request(url, https, cache and filename)
      else
         https_err = true
      end
   else
      err = "Unsupported protocol"
   end
   if https_err then
      if not downloader_warning then
         util.printerr("Warning: falling back to "..cfg.downloader.." - install luasec to get native HTTPS support")
         downloader_warning = true
      end
      return fs.use_downloader(url, filename, cache)
   end
   if cache and content == true then
      return true, filename
   end
   if not content then
      return false, tostring(err)
   end
   local file = io.open(filename, "wb")
   if not file then return false end
   file:write(content)
   file:close()
   return true, filename
end

else --...if socket_ok == false then

function fs_lua.download(url, filename, cache)
   return fs.use_downloader(url, filename, cache)
end

end
---------------------------------------------------------------------
-- MD5 functions
---------------------------------------------------------------------

if md5_ok then

-- Support the interface of lmd5 by lhf in addition to md5 by Roberto
-- and the keplerproject.
if not md5.sumhexa and md5.digest then
   md5.sumhexa = function(msg)
      return md5.digest(msg)
   end
end

--- Get the MD5 checksum for a file.
-- @param file string: The file to be computed.
-- @return string: The MD5 checksum or nil + error
function fs_lua.get_md5(file)
   file = fs.absolute_name(file)
   local file_handler = io.open(file, "rb")
   if not file_handler then return nil, "Failed to open file for reading: "..file end
   local computed = md5.sumhexa(file_handler:read("*a"))
   file_handler:close()
   if computed then return computed end
   return nil, "Failed to compute MD5 hash for file "..file
end

end

---------------------------------------------------------------------
-- POSIX functions
---------------------------------------------------------------------

if posix_ok then

local octal_to_rwx = {
   ["0"] = "---",
   ["1"] = "--x",
   ["2"] = "-w-",
   ["3"] = "-wx",
   ["4"] = "r--",
   ["5"] = "r-x",
   ["6"] = "rw-",
   ["7"] = "rwx",
}

function fs_lua.chmod(file, mode)
   -- LuaPosix (as of 5.1.15) does not support octal notation...
   if mode:sub(1,1) == "0" then
      local new_mode = {}
      for c in mode:sub(-3):gmatch(".") do
         table.insert(new_mode, octal_to_rwx[c])
      end
      mode = table.concat(new_mode)
   end
   local err = posix.chmod(file, mode)
   return err == 0
end

function fs_lua.attributes(file, attrtype)
   if attrtype == "permissions" then
      return posix.stat(file, "mode") or nil
   elseif attrtype == "owner" then
      local uid = posix.stat(file, "uid")
      if not uid then return nil end
      return posix.getpwuid(uid).pw_name or nil
   else
      return nil
   end
end

function fs_lua.current_user()
   return posix.getpwuid(posix.geteuid()).pw_name
end

--- Create a temporary directory.
-- @param name string: name pattern to use for avoiding conflicts
-- when creating temporary directory.
-- @return string or (nil, string): name of temporary directory or (nil, error message) on failure.
function fs_lua.make_temp_dir(name)
   assert(type(name) == "string")
   name = dir.normalize(name)

   return posix.mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/luarocks_" .. name:gsub(dir.separator, "_") .. "-XXXXXX")
end

end

---------------------------------------------------------------------
-- Other functions
---------------------------------------------------------------------

--- Apply a patch.
-- @param patchname string: The filename of the patch.
-- @param patchdata string or nil: The actual patch as a string.
function fs_lua.apply_patch(patchname, patchdata)
   local p, all_ok = patch.read_patch(patchname, patchdata)
   if not all_ok then
      return nil, "Failed reading patch "..patchname
   end
   if p then
      return patch.apply_patch(p, 1)
   end
end

--- Move a file.
-- @param src string: Pathname of source
-- @param dest string: Pathname of destination
-- @param perms string or nil: Permissions for destination file,
-- or nil to use the source filename permissions.
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function fs_lua.move(src, dest, perms)
   assert(src and dest)
   if fs.exists(dest) and not fs.is_dir(dest) then
      return false, "File already exists: "..dest
   end
   local ok, err = fs.copy(src, dest, perms)
   if not ok then
      return false, err
   end
   fs.delete(src)
   if fs.exists(src) then
      return false, "Failed move: could not delete "..src.." after copy."
   end
   return true
end

--- Check if user has write permissions for the command.
-- Assumes the configuration variables under cfg have been previously set up.
-- @param flags table: the flags table passed to run() drivers.
-- @return boolean or (boolean, string): true on success, false on failure,
-- plus an error message.
function fs_lua.check_command_permissions(flags)
   local ok = true
   local err = ""
   for _, directory in ipairs { cfg.rocks_dir, cfg.deploy_lua_dir, cfg.deploy_bin_dir, cfg.deploy_lua_dir } do
      if fs.exists(directory) then
         if not fs.is_writable(directory) then
            ok = false
            err = "Your user does not have write permissions in " .. directory
            break
         end
      else
         local root = fs.root_of(directory)
         local parent = directory
         repeat
            parent = dir.dir_name(parent)
            if parent == "" then
               parent = root
            end
         until parent == root or fs.exists(parent)
         if not fs.is_writable(parent) then
            ok = false
            err = directory.." does not exist and your user does not have write permissions in " .. parent
            break
         end
      end
   end
   if ok then
      return true
   else
      if flags["local"] then
         err = err .. " \n-- please check your permissions."
      else
         err = err .. " \n-- you may want to run as a privileged user or use your local tree with --local."
      end
      return nil, err
   end
end

--- Check whether a file is a Lua script
-- When the file can be succesfully compiled by the configured
-- Lua interpreter, it's considered to be a valid Lua file.
-- @param name filename of file to check
-- @return boolean true, if it is a Lua script, false otherwise
function fs_lua.is_lua(name)
  name = name:gsub([[%\]],"/")   -- normalize on fw slash to prevent escaping issues
  local lua = fs.Q(dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter))  -- get lua interpreter configured
  -- execute on configured interpreter, might not be the same as the interpreter LR is run on
  local result = fs.execute_string(lua..[[ -e "if loadfile(']]..name..[[') then os.exit() else os.exit(1) end"]])
  return (result == true) 
end

return fs_lua
