
--- Module implementing the luarocks-admin "refresh_cache" command.
module("luarocks.refresh_cache", package.seeall)

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local cache = require("luarocks.cache")

help_summary = "Refresh local cache of a remote rocks server."
help_arguments = "[--from=<server>]"
help = [[
The flag --from indicates which server to use.
If not given, the default server set in the upload_server variable
from the configuration file is used instead.
]]

function run(...)
   local flags = util.parse_flags(...)
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

