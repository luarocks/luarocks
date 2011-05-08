
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
help_arguments = "[--to=<server>] [--no-refresh] {<rockspec>|<rock>...}"
help = [[
Arguments are local files, which may be rockspecs or rocks.
The flag --to indicates which server to use.
If not given, the default server set in the upload_server variable
from the configuration file is used instead.
The flag --no-refresh indicates the local cache should not be refreshed
prior to generation of the updated manifest.
]]

local function add_files_to_server(refresh, rockfiles, server, upload_server)
   assert(type(refresh) == "boolean" or not refresh)
   assert(type(rockfiles) == "table")
   assert(type(server) == "string")
   assert(type(upload_server) == "table" or not upload_server)

   local download_url = server
   local login_url = nil
   if upload_server then
      if upload_server.rsync then download_url = "rsync://"..upload_server.rsync
      elseif upload_server.http then download_url = "http://"..upload_server.http
      elseif upload_server.ftp then download_url = "ftp://"..upload_server.ftp
      end
      
      if upload_server.ftp then login_url = "ftp://"..upload_server.ftp
      elseif upload_server.sftp then login_url = "sftp://"..upload_server.sftp
      end
   end
   
   local at = fs.current_dir()
   
   local refresh_fn = refresh and cache.refresh_local_cache or cache.split_server_url
   local local_cache, protocol, server_path, user, password = refresh_fn(server, download_url, cfg.upload_user, cfg.upload_password)
   if not local_cache then
      return nil, protocol
   end
   if protocol == "file" then
      return nil, "Server "..server.." is not recognized, check your configuration."
   end
   
   if not login_url then
      login_url = protocol.."://"..server_path
   end
   
   fs.change_dir(at)
   
   local files = {}
   for i, rockfile in ipairs(rockfiles) do
      if fs.exists(rockfile) then
         print("Copying file "..rockfile.." to "..local_cache.."...")
         local absolute = fs.absolute_name(rockfile)
         fs.copy(absolute, local_cache)
         table.insert(files, dir.base_name(absolute))
      else
         print("File "..rockfile.." not found")
      end
   end
   if #files == 0 then
      return nil, "No files found"
   end

   fs.change_dir(local_cache)

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

   local cmd
   if protocol == "rsync" then
      local srv, path = server_path:match("([^/]+)(/.+)")
      cmd = "rsync --exclude=.git -Oavz -e ssh "..local_cache.."/ "..user.."@"..srv..":"..path.."/"
   elseif upload_server and upload_server.sftp then
      local part1, part2 = upload_server.sftp:match("^([^/]*)/(.*)$")
      cmd = "scp manifest index.html "..table.concat(files, " ").." "..user.."@"..part1..":/"..part2
   else
      cmd = "curl "..login_info.." -T '{manifest,index.html,"..table.concat(files, ",").."}' "..login_url
   end

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
   local server = flags["to"]
   if not server then server = cfg.upload_server end
   if not server then
      return nil, "No server specified with --to and no default configured with upload_server."
   end
   
   return add_files_to_server(not flags["no-refresh"], files, server, cfg.upload_servers and cfg.upload_servers[server])
end

