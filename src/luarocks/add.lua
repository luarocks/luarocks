
--- Module implementing the luarocks-admin "add" command.
-- Adds a rock or rockspec to a rocks server.
module("luarocks.add", package.seeall)

local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")
local fs = require("luarocks.fs")

help_summary = "Add a rock or rockpec to a rocks server."
help_arguments = "[--to=<server>] {<rockspec>|<rock>]}"
help = [[
Argument may be a local rockspec or rock file.
The flag --to indicates which server to use.
If not given, the default server set in the upload_server variable
from the configuration file is used instead.
]]

local function split_server_url(server, user, password)
   local protocol, server_path = dir.split_url(server)
   if server_path:match("@") then
      local credentials
      credentials, server_path = server_path:match("([^@]*)@(.*)")
      if credentials:match(":") then
         user, password = credentials:match("([^:]*):(.*)")
      else
         user = credentials
      end
   end
   local local_cache
   if cfg.local_cache then
      local_cache = cfg.local_cache .. "/" .. server_path
   end
   return local_cache, protocol, server_path, user, password
end

local function refresh_local_cache(server, user, password)
   local local_cache, protocol, server_path, user, password = split_server_url(server, user, password)

   fs.make_dir(cfg.local_cache)

   local tmp_cache = false
   if not local_cache then
      local_cache = fs.make_temp_dir("local_cache")
      tmp_cache = true
   end
   local ok = fs.make_dir(local_cache)
   if not ok then
      return nil, "Failed creating local cache dir."
   end
   fs.change_dir(local_cache)
   print("Refreshing cache "..local_cache.."...")

   local login_info = ""
   if user then login_info = " --user="..user end
   if password then login_info = login_info .. " --password="..password end

   fs.execute("wget -q -m -nd "..protocol.."://"..server_path..login_info)
   return local_cache, protocol, server_path, user, password
end

local function add_file_to_server(refresh, rockfile, server)
   if not fs.exists(rockfile) then
      return nil, "Could not find "..rockfile
   end

   local rockfile = fs.absolute_name(rockfile)

   local local_cache, protocol, server_path, user, password
   if refresh then
      local_cache, protocol, server_path, user, password = refresh_local_cache(server, cfg.upload_user, cfg.upload_password)
   else
      local_cache, protocol, server_path, user, password = split_server_url(server, cfg.upload_user, cfg.upload_password)
   end
   fs.change_dir(local_cache)
   print("Copying file "..rockfile.." to "..local_cache.."...")
   fs.copy(rockfile, local_cache)

   print("Updating manifest...")
   manif.make_manifest(local_cache)
   print("Updating index.html...")
   manif.make_index(local_cache)

   local login_info = ""
   if user then login_info = " -u "..user end
   if password then login_info = login_info..":"..password end
   if not server_path:match("/$") then
      server_path = server_path .. "/"
   end
   fs.execute("curl "..login_info.." -T '{manifest,index.html,"..dir.base_name(rockfile).."}' "..protocol.."://"..server_path)

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
   if cfg.upload_aliases then
      server = cfg.upload_aliases[server] or server
   end
   return add_file_to_server(not flags["no-refresh"], file, server)
end

