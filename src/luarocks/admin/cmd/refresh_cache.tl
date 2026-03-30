
--- Module implementing the luarocks-admin "refresh_cache" command.
local record refresh_cache
end

local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local cache = require("luarocks.admin.cache")

local type Parser = require("luarocks.vendor.argparse").Parser

local type Args = require("luarocks.core.types.args").Args

function refresh_cache.add_to_parser(parser: Parser)
   local cmd = parser:command("refresh_cache", "Refresh local cache of a remote rocks server.", util.see_also())

   cmd:option("--from", "The server to use. If not given, the default server "..
      "set in the upload_server variable from the configuration file is used instead.")
      :argname("<server>")
end

function refresh_cache.command(args: Args): boolean, string
   local server, upload_server, err = cache.get_upload_server(args.server)
   if not server then return nil, err end
   local download_url = cache.get_server_urls(server, upload_server)

   local local_cache: string
   local_cache, err = cache.refresh_local_cache(download_url, cfg.upload_user, cfg.upload_password)
   if not local_cache then
      return nil, err
   else
      return true
   end
end


return refresh_cache
