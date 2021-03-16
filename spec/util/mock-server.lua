#!/usr/bin/env lua

--- A simple LuaRocks mock-server for testing.
local restserver = require("restserver")
local server = restserver:new():port(8080)

server:add_resource("api/tool_version", {
   {
      method = "GET",
      path = "/",
      produces = "application/json",
      handler = function(query)
         local json = { version = query.current }
         return restserver.response():status(200):entity(json)
      end
   }
})

server:add_resource("api/1/{id:[0-9]+}/status", {
   {
      method = "GET",
      path = "/",
      produces = "application/json",
      handler = function(query)
         local json = { user_id = "123", created_at = "29.1.1993" }
         return restserver.response():status(200):entity(json)
      end
   }
})

server:add_resource("/api/1/{id:[0-9]+}/check_rockspec", {
   {
      method = "GET",
      path = "/",
      produces = "application/json",
      handler = function(query)
         local json = {}
         return restserver.response():status(200):entity(json)
      end
   }
})

server:add_resource("/api/1/{id:[0-9]+}/upload", {
   {
      method = "POST",
      path = "/",
      produces = "application/json",
      handler = function(query)
         local json = {module = "luasocket", version = {id = "1.0"}, module_url = "http://localhost/luasocket", manifests = "root", is_new = "is_new"}
         return restserver.response():status(200):entity(json)
      end
   }
})

server:add_resource("/api/1/{id:[0-9]+}/upload_rock/{id:[0-9]+}", {
   {
      method = "POST",
      path = "/",
      produces = "application/json",
      handler = function(query)
         local json = {"rock","module_url"}
         return restserver.response():status(200):entity(json)
      end
   }
})

server:add_resource("/file/{name:[^/]+}", {
   {
      method = "GET",
      path = "/",
      produces = "text/plain",
      handler = function(query, name)
         local basedir = arg[1] or "./spec/fixtures"
         local fd = io.open(basedir .. "/" .. name, "rb")
         if not fd then
            return restserver.response():status(404)
         end
         local data = fd:read("*a")
         fd:close()
         return restserver.response():status(200):entity(data)
      end
   }
})

-- SHUTDOWN this mock-server
server:add_resource("/shutdown", {
   {
      method = "GET",
      path = "/",
      handler = function(query)
         os.exit()
         return restserver.response():status(200):entity()
      end
   }
})

-- This loads the restserver.xavante plugin
server:enable("restserver.xavante"):start()
