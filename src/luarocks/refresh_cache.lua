
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
   local server = flags["from"]
   if not server then server = cfg.upload_server end
   if not server then
      return nil, "No server specified with --from and no default configured with upload_server."
   end
   if cfg.upload_servers and cfg.upload_servers[server] and cfg.upload_servers[server].http then
      server = "http://"..cfg.upload_servers[server].http
   end
   local ok, err = cache.refresh_local_cache(server, cfg.upload_user, cfg.upload_password)
   if not ok then
      return nil, err
   else
      return true
   end
end

