
--- Common fs operations implemented with third-party tools.
local tools = {}

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

local vars = cfg.variables

local dir_stack = {}

--- Obtain current directory.
-- Uses the module's internal directory stack.
-- @return string: the absolute pathname of the current directory.
function tools.current_dir()
   local current = cfg.cache_pwd
   if not current then
      local pipe = io.popen(fs.quiet_stderr(fs.Q(vars.PWD)))
      current = pipe:read("*l")
      pipe:close()
      cfg.cache_pwd = current
   end
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

--- Run the given command.
-- The command is executed in the current directory in the directory stack.
-- @param cmd string: No quoting/escaping is applied to the command.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
function tools.execute_string(cmd)
   local current = fs.current_dir()
   if not current then return false end
   cmd = fs.command_at(current, cmd)
   local code = os.execute(cmd)
   if code == 0 or code == true then
      return true
   else
      return false
   end
end

--- Internal implementation function for fs.dir.
-- Yields a filename on each iteration.
-- @param at string: directory to list
-- @return nil
function tools.dir_iterator(at)
   local pipe = io.popen(fs.command_at(at, fs.Q(vars.LS)))
   for file in pipe:lines() do
      if file ~= "." and file ~= ".." then
         coroutine.yield(file)
      end
   end
   pipe:close()
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
        wget_cmd = wget_cmd .. "--timeout="..tostring(cfg.connection_timeout).." --tries=1 "
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
        curl_cmd = curl_cmd .. "--connect-timeout "..tostring(cfg.connection_timeout).." "
      end
      ok = fs.execute_string(fs.quiet_stderr(curl_cmd..fs.Q(url).." > "..fs.Q(filename)))
   end
   if ok then
      return true, filename
   else
      return false
   end
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

return tools
