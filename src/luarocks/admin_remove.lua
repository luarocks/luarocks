
--- Module implementing the luarocks-admin "remove" command.
-- Removes a rock or rockspec from a rocks server.
module("luarocks.admin_remove", package.seeall)

local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")
local index = require("luarocks.index")
local fs = require("luarocks.fs")
local cache = require("luarocks.cache")

help_summary = "Remove a rock or rockspec from a rocks server."
help_arguments = "[--from=<server>] [--no-refresh] {<rockspec>|<rock>...}"
help = [[
Arguments are local files, which may be rockspecs or rocks.
The flag --from indicates which server to use.
If not given, the default server set in the upload_server variable
from the configuration file is used instead.
The flag --no-refresh indicates the local cache should not be refreshed
prior to generation of the updated manifest.
]]

local function remove_files_from_server(refresh, rockfiles, server, upload_server)
   assert(type(refresh) == "boolean" or not refresh)
   assert(type(rockfiles) == "table")
   assert(type(server) == "string")
   assert(type(upload_server) == "table" or not upload_server)

   local download_url = server
   if upload_server then
      if upload_server.rsync then
         download_url = "rsync://"..upload_server.rsync
      else
         return nil, "This command requires 'rsync', check your configuration."
      end
   end
   
   local at = fs.current_dir()
   
   local refresh_fn = refresh and cache.refresh_local_cache or cache.split_server_url
   local local_cache, protocol, server_path, user, password = refresh_fn(server, download_url, cfg.upload_user, cfg.upload_password)
   if not local_cache then
      return nil, protocol
   end
   if protocol ~= "rsync" then
      return nil, "This command requires 'rsync', check your configuration."
   end
   
   fs.change_dir(at)
   
   local nr_files = 0
   for i, rockfile in ipairs(rockfiles) do
      local basename = dir.base_name(rockfile)
      local file = dir.path(local_cache, basename)
      print("Removing file "..file.."...")
      if fs.delete(file) then
         nr_files = nr_files + 1
      else
         print("Failed removing "..file)
      end
   end
   if nr_files == 0 then
      return nil, "No files removed."
   end

   fs.change_dir(local_cache)

   print("Updating manifest...")
   manif.make_manifest(local_cache)
   print("Updating index.html...")
   index.make_index(local_cache)

   local srv, path = server_path:match("([^/]+)(/.+)")
   local cmd = "rsync -Oavz --delete -e ssh "..local_cache.."/ "..user.."@"..srv..":"..path.."/"

   print(cmd)
   fs.execute(cmd)

   return true
end

function run(...)
   local files = { util.parse_flags(...) }
   local flags = table.remove(files, 1)
   if #files < 1 then
      return nil, "Argument missing, see help."
   end
   local server = flags["from"]
   if not server then server = cfg.upload_server end
   if not server then
      return nil, "No server specified with --to and no default configured with upload_server."
   end
   
   return remove_files_from_server(not flags["no-refresh"], files, server, cfg.upload_servers and cfg.upload_servers[server])
end

