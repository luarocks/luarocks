
--- Module handling the LuaRocks local cache.
-- Adds a rock or rockspec to a rocks server.
module("luarocks.cache", package.seeall)

local fs = require("luarocks.fs")
local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

function split_server_url(server, user, password)
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

function refresh_local_cache(server, user, password)
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

   -- TODO abstract away explicit 'wget' call
   local ok = fs.execute("wget --no-cache -q -m -np -nd "..protocol.."://"..server_path..login_info)
   if not ok then
      return nil, "Failed downloading cache."
   end
   return local_cache, protocol, server_path, user, password
end

