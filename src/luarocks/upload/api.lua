
local api = {}

local cfg = require("luarocks.cfg")
local fs = require("luarocks.fs")
local util = require("luarocks.util")
local persist = require("luarocks.persist")
local multipart = require("luarocks.upload.multipart")

local Api = {}

local function upload_config_file()
   local _, _, home_conf, home_ok = cfg.which_config()
   if not home_conf then
      return nil
   end
   return (home_conf:gsub("/[^/]+$", "/upload_config.lua"))
end

function Api:load_config()
   local upload_conf = upload_config_file()
   print(upload_conf)
   if not upload_conf then return nil end
   local cfg, err = persist.load_into_table(upload_conf)
   return cfg
end

function Api:save_config()
   -- Test configuration before saving it.
   local res, err = self:raw_method("status")
   if not res then
      return nil, err
   end
   if res.errors then
      util.printerr("Server says: " .. tostring(res.errors[1]))
      return
   end
   local upload_conf = upload_config_file()
   if not upload_conf then return nil end
   persist.save_from_table(upload_conf, self.config)
   fs.chmod(upload_conf, "0600")
end

function Api:check_version()
   if not self._server_tool_version then
      local tool_version = cfg.upload.tool_version
      local res, err = self:request(tostring(self.config.server) .. "/api/tool_version", {
        current = tool_version
      })
      if not res then
         return nil, err
      end
      if not res.version then
         return nil, "failed to fetch tool version"
      end
      self._server_tool_version = res.version
      if res.force_update then
         return nil, "Your upload client is too out of date to continue, please upgrade LuaRocks."
      end
      if res.version ~= tool_version then
         util.printerr("Warning: Your LuaRocks is out of date, consider upgrading.")
      end
   end
   return true
end

function Api:method(...)
   local res, err = self:raw_method(...)
   if not res then
      return nil, err
   end
   if res.errors then
      if res.errors[1] == "Invalid key" then
         return nil, res.errors[1] .. " (use the --api-key flag to change)"
      end
      local msg = table.concat(res.errors, ", ")
      return nil, "API Failed: " .. msg
   end
   return res
end

function Api:raw_method(path, ...)
   self:check_version()
   local url = tostring(self.config.server) .. "/api/" .. tostring(cfg.upload.api_version) .. "/" .. tostring(self.config.key) .. "/" .. tostring(path)
   return self:request(url, ...)
end

local function encode_query_string(t, sep)
   if sep == nil then
      sep = "&"
   end
   local i = 0
   local buf = { }
   for k, v in pairs(t) do
      if type(k) == "number" and type(v) == "table" then
         k, v = v[1], v[2]
      end
      buf[i + 1] = multipart.url_escape(k)
      buf[i + 2] = "="
      buf[i + 3] = multipart.url_escape(v)
      buf[i + 4] = sep
      i = i + 4
   end
   buf[i] = nil
   return table.concat(buf)
end

-- An ode to the multitude of JSON libraries out there...
local function require_json()
   for _, lib in ipairs({ "cjson", "dkjson", "json" }) do
      local json_ok, json = pcall(require, lib)
      if json_ok then
         return json_ok, json
      end
   end
   return nil
end

local ltn12_ok, ltn12 = pcall(require, "ltn12")
if not ltn12_ok then -- If not using LuaSocket and/or LuaSec...

function Api:request(url, params, post_params)
   local vars = cfg.variables
   local json_ok, json = require_json()
   if not json_ok then return nil, "A JSON library is required for this command." end
   
   if cfg.downloader == "wget" then
      local curl_ok = fs.execute_quiet(vars.CURL, "--version")
      if not curl_ok then
         return nil, "Missing network helper program 'curl'.\nMake sure 'curl' is installed and available from your path."
      end
   end

   if not self.config.key then
      return nil, "Must have API key before performing any actions."
   end
   local body
   local headers = {}
   if params and next(params) then
      url = url .. ("?" .. encode_query_string(params))
   end
   local method = "GET"
   local out 
   local tmpfile = fs.tmpname()
   if post_params then
      method = "POST"
      local curl_cmd = fs.Q(vars.CURL).." -f -k -L --silent --user-agent \""..cfg.user_agent.." via curl\" "
      for k,v in pairs(post_params) do
         local var = v
         if type(v) == "table" then
            var = "@"..v.fname
         end
         curl_cmd = curl_cmd .. "--form \""..k.."="..var.."\" "
      end
      if cfg.connection_timeout and cfg.connection_timeout > 0 then
        curl_cmd = curl_cmd .. "--connect-timeout "..tonumber(cfg.connection_timeout).." " 
      end
      local ok = fs.execute_string(curl_cmd..fs.Q(url).." -o "..fs.Q(tmpfile))
      if not ok then
         return nil, "API failure: " .. tostring(url)
      end
   else
      local ok, err = fs.download(url, tmpfile)
      if not ok then
         return nil, "API failure: " .. tostring(err) .. " - " .. tostring(url)
      end
   end

   local tmpfd = io.open(tmpfile)
   if not tmpfd then
      os.remove(tmpfile)
      return nil, "API failure reading temporary file - " .. tostring(url)
   end
   out = tmpfd:read("*a")
   tmpfd:close()
   os.remove(tmpfile)

   if self.debug then
      util.printout("[" .. tostring(method) .. " via curl] " .. tostring(url) .. " ... ")
   end

   return json.decode(out)
end

else -- use LuaSocket and LuaSec

local warned_luasec = false

function Api:request(url, params, post_params)
   local json_ok, json = require_json()
   if not json_ok then return nil, "A JSON library is required for this command." end
   local server = tostring(self.config.server)
   local http_ok, http
   local via = "luasocket"
   if server:match("^https://") then
      http_ok, http = pcall(require, "ssl.https")
      if http_ok then
         via = "luasec"
      else
         if not warned_luasec then
            util.printerr("LuaSec is not available; using plain HTTP. Install 'luasec' to enable HTTPS.")
            warned_luasec = true
         end
         http_ok, http = pcall(require, "socket.http")
         server = server:gsub("^https", "http")
         url = url:gsub("^https", "http")
         via = "luasocket"
      end
   else
      http_ok, http = pcall(require, "socket.http")
   end
   if not http_ok then
      return nil, "Failed loading socket library!"
   end
   
   if not self.config.key then
      return nil, "Must have API key before performing any actions."
   end
   local body
   local headers = {}
   if params and next(params) then
      url = url .. ("?" .. encode_query_string(params))
   end
   if post_params then
      local boundary
      body, boundary = multipart.encode(post_params)
      headers["Content-length"] = #body
      headers["Content-type"] = "multipart/form-data; boundary=" .. tostring(boundary)
   end
   local method = post_params and "POST" or "GET"
   if self.debug then
      util.printout("[" .. tostring(method) .. " via "..via.."] " .. tostring(url) .. " ... ")
   end
   local out = {}
   local _, status = http.request({
      url = url,
      headers = headers,
      method = method,
      sink = ltn12.sink.table(out),
      source = body and ltn12.source.string(body)
   })
   if self.debug then
      util.printout(tostring(status))
   end
   if status ~= 200 then
      return nil, "API returned " .. tostring(status) .. " - " .. tostring(url)
   end
   return json.decode(table.concat(out))
end

end

function api.new(flags, name)
   local self = {}
   setmetatable(self, { __index = Api })
   self.config = self:load_config() or {}
   self.config.server = flags["server"] or self.config.server or cfg.upload.server
   self.config.version = self.config.version or cfg.upload.version
   self.config.key = flags["api-key"] or self.config.key
   self.debug = flags["debug"]
   if not self.config.key then
      return nil, "You need an API key to upload rocks.\n" ..
                  "Navigate to "..self.config.server.."/settings to get a key\n" ..
                  "and then pass it through the --api-key=<key> flag."
   end
   if flags["api-key"] then
      self:save_config()
   end
   return self
end

return api

