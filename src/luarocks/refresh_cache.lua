
module("luarocks.refresh_cache", package.seeall)

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local cache = require("luarocks.cache")

function run(...)
   local flags = util.parse_flags(...)
   local server = flags["to"]
   if not server then server = cfg.upload_server end
   if not server then
      return nil, "No server specified with --to and no default configured with upload_server."
   end
   if cfg.upload_aliases then
      server = cfg.upload_aliases[server] or server
   end
   local ok, err = cache.refresh_local_cache(server, cfg.upload_user, cfg.upload_password)
   if not ok then
      return nil, err
   else
      return true
   end
end

