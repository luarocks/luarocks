
--- Module implementing the luarocks-admin "refresh_cache" command.
local refresh_cache = {}
package.loaded["luarocks.refresh_cache"] = refresh_cache

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local cache = require("luarocks.cache")

util.add_run_function(refresh_cache)
refresh_cache.help_summary = "Refresh local cache of a remote rocks server."
refresh_cache.help_arguments = "[--from=<server>]"
refresh_cache.help = [[
The flag --from indicates which server to use.
If not given, the default server set in the upload_server variable
from the configuration file is used instead.
]]

function refresh_cache.command(flags)
   local server, upload_server = cache.get_upload_server(flags["server"])
   if not server then return nil, upload_server end
   local download_url = cache.get_server_urls(server, upload_server)
   
   local ok, err = cache.refresh_local_cache(server, download_url, cfg.upload_user, cfg.upload_password)
   if not ok then
      return nil, err
   else
      return true
   end
end


return refresh_cache
