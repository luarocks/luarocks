
--- Module implementing the luarocks-admin "add" command.
-- Adds a rock or rockspec to a rocks server.
module("luarocks.add", package.seeall)

local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")
local index = require("luarocks.index")
local fs = require("luarocks.fs")
local cache = require("luarocks.cache")

help_summary = "Add a rock or rockspec to a rocks server."
help_arguments = "[--to=<server>] [--no-refresh] {<rockspec>|<rock>]}"
help = [[
Argument may be a local rockspec or rock file.
The flag --to indicates which server to use.
If not given, the default server set in the upload_server variable
from the configuration file is used instead.
The flag --no-refresh indicates the local cache should not be refreshed
prior to generation of the updated manifest.
]]

local function add_file_to_server(refresh, rockfile, server, upload_server)
   assert(type(refresh) == "boolean" or not refresh)
   assert(type(rockfile) == "string")
   assert(type(server) == "string")
   assert(type(upload_server) == "table" or not upload_server)

   if not fs.exists(rockfile) then
      return nil, "Could not find "..rockfile
   end
   
   local download_url = server
   local login_url = nil
   if upload_server then
      if upload_server.http then download_url = "http://"..upload_server.http
      elseif upload_server.ftp then download_url = "ftp://"..upload_server.ftp
      end
      if upload_server.ftp then login_url = "ftp://"..upload_server.ftp
      elseif upload_server.sftp then login_url = "sftp://"..upload_server.sftp
      end
   end

   local rockfile = fs.absolute_name(rockfile)

   local local_cache, protocol, server_path, user, password
   if refresh then
      local_cache, protocol, server_path, user, password = cache.refresh_local_cache(download_url, cfg.upload_user, cfg.upload_password)
   else
      local_cache, protocol, server_path, user, password = cache.split_server_url(download_url, cfg.upload_user, cfg.upload_password)
   end
   if not local_cache then
      return nil, protocol
   end
   if not login_url then
      login_url = protocol.."://"..server_path
   end
   fs.change_dir(local_cache)
   print("Copying file "..rockfile.." to "..local_cache.."...")
   fs.copy(rockfile, local_cache)

   print("Updating manifest...")
   manif.make_manifest(local_cache)
   print("Updating index.html...")
   index.make_index(local_cache)

   local login_info = ""
   if user then login_info = " -u "..user end
   if password then login_info = login_info..":"..password end
   if not login_url:match("/$") then
      login_url = login_url .. "/"
   end

   -- TODO abstract away explicit 'curl' call

   print ("curl "..login_info.." -T '{manifest,index.html,"..dir.base_name(rockfile).."}' "..login_url)

   fs.execute("curl "..login_info.." -T '{manifest,index.html,"..dir.base_name(rockfile).."}' "..login_url)

   return true
end

function run(...)
   local flags, file = util.parse_flags(...)
   if type(file) ~= "string" then
      return nil, "Argument missing, see help."
   end
   local server = flags["to"]
   if not server then server = cfg.upload_server end
   if not server then
      return nil, "No server specified with --to and no default configured with upload_server."
   end
   return add_file_to_server(not flags["no-refresh"], file, server, cfg.upload_servers and cfg.upload_servers[server])
end

