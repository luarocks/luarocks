
--- Common fs operations implemented with third-party tools.
local tools = {}

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

local vars = cfg.variables

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
      ok = fs.execute_string(fs.quiet_stderr(curl_cmd..fs.Q(url).." > "..fs.Q(filename)))
   end
   if ok then
      return true, filename
   else
      return false
   end
end

return tools
