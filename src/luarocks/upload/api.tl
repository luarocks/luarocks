local record api
   record Configuration
      key: string
      server: string
      version: string
   end

   record Api
      load_config: function(Api): Configuration
      save_config: function(Api): boolean, string
      check_version: function(Api): boolean, string
      method: function(Api, string, ...:Parameters): {string : any}, string
      raw_method: function(Api, string, ...:Parameters): {string : any}, string
      request: function(Api, string, ?Parameters, ?Parameters): {string : any}, string
      config: Configuration
      debug: boolean
      _server_tool_version: string
   end
end

local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local persist = require("luarocks.persist")
local multipart = require("luarocks.upload.multipart")
local json = require("luarocks.vendor.dkjson")
local dir_sep = package.config:sub(1, 1)

local type Parameters = multipart.Parameters
local type Api = api.Api
local type Args = require("luarocks.core.types.args").Args
local type Configuration = api.Configuration
local type File = multipart.File

local type PersistableTable = require("luarocks.core.types.persist").PersistableTable

local function upload_config_file(): string
   if not cfg.config_files.user.file then
      return nil
   end
   return (cfg.config_files.user.file:gsub("[\\/][^\\/]+$", dir_sep .. "upload_config.lua"))
end

function api.Api:load_config(): Configuration
   local upload_conf = upload_config_file()
   if not upload_conf then return nil end
   local config = persist.load_into_table(upload_conf) as Configuration
   return config
end

function api.Api:save_config(): boolean, string
   -- Test configuration before saving it.
   local res, errraw = self:raw_method("status")
   if not res then
      return nil, errraw
   end
   local reserrors = res.errors
   if reserrors is {string} then
      return nil, ("Server error: " .. tostring(reserrors[1]))
   end
   local upload_conf = upload_config_file()
   if not upload_conf then return nil end
   local ok, errmake = fs.make_dir(dir.dir_name(upload_conf))
   if not ok then
      return nil, errmake
   end
   persist.save_from_table(upload_conf, self.config as PersistableTable)
   fs.set_permissions(upload_conf, "read", "user")
   return true
end

function api.Api:check_version(): boolean, string
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
      self._server_tool_version = tostring(res.version)
      if res.force_update then
         return nil, "Your upload client is too out of date to continue, please upgrade LuaRocks."
      end
      if res.version ~= tool_version then
         util.warning("your LuaRocks is out of date, consider upgrading.")
      end
   end
   return true
end

function api.Api:method(path: string, ...: Parameters): {string : any}, string
   local res, err = self:raw_method(path, ...)
   if not res then
      return nil, err
   end
   local reserrors = res.errors
   if reserrors is {string} then --! not checking the contents
      if reserrors[1] == "Invalid key" then
         return nil, reserrors[1] .. " (use the --api-key flag to change)"
      end
      local msg = table.concat(reserrors, ", ")
      return nil, "API Failed: " .. msg
   end
   return res
end

function api.Api:raw_method(path: string, ...: Parameters): {string : any}, string
   self:check_version()
   local url = tostring(self.config.server) .. "/api/" .. tostring(cfg.upload.api_version) .. "/" .. tostring(self.config.key) .. "/" .. path
   return self:request(url, ...)
end

local function encode_query_string(t: Parameters, sep?: string): string
   if sep == nil then
      sep = "&"
   end
   local i = 0
   local buf: {string} = { }
   for k, v in pairs(t) do
      local ks, vs: string, string
      local vf = v
      if vf is File then
         ks, vs = k, vf:content()
      else
         ks, vs = k, vf
      end
      buf[i + 1] = multipart.url_escape(ks)
      buf[i + 2] = "="
      buf[i + 3] = multipart.url_escape(vs)
      buf[i + 4] = sep
      i = i + 4
   end
   buf[i] = nil
   return table.concat(buf)
end

local function redact_api_url(url: any): string
   local urls = tostring(url)
   return (urls:gsub(".*/api/[^/]+/[^/]+", "")) or ""
end

local ltn12_ok, ltn12 = pcall(require, "ltn12")
if not ltn12_ok then -- If not using LuaSocket and/or LuaSec...

   api.Api.request = function(self: Api, url: string, params?: Parameters, post_params?: Parameters): {string : any}, string
      local vars = cfg.variables

      if fs.which_tool("downloader") == "wget" then
         local curl_ok, err = fs.is_tool_available(vars.CURL, "curl")
         if not curl_ok then
            return nil, err
         end
      end

      if not self.config.key then
         return nil, "Must have API key before performing any actions."
      end
      if params and next(params) then
         url = url .. ("?" .. encode_query_string(params))
      end
      local method = "GET"
      local out: string
      local tmpfile = fs.tmpname()
      if post_params then
         method = "POST"
         local curl_cmd = vars.CURL.." "..vars.CURLNOCERTFLAG.." -f -L --silent --user-agent \""..cfg.user_agent.." via curl\" "
         for k,v in pairs(post_params) do
            local var: string
            if v is File then
               var = "@"..v.fname
            else
               var = v
            end
            curl_cmd = curl_cmd .. "--form \""..k.."="..var.."\" "
         end
         if cfg.connection_timeout and cfg.connection_timeout > 0 then
         curl_cmd = curl_cmd .. "--connect-timeout "..tonumber(cfg.connection_timeout).." "
         end
         local ok = fs.execute_string(curl_cmd..fs.Q(url).." -o "..fs.Q(tmpfile))
         if not ok then
            return nil, "API failure: " .. redact_api_url(url)
         end
      else
         local name, err = fs.download(url, tmpfile)
         if not name then
            return nil, "API failure: " .. tostring(err) .. " - " .. redact_api_url(url)
         end
      end

      local tmpfd = io.open(tmpfile)
      if not tmpfd then
         os.remove(tmpfile)
         return nil, "API failure reading temporary file - " .. redact_api_url(url)
      end
      out = tmpfd:read("*a")
      tmpfd:close()
      os.remove(tmpfile)

      if self.debug then
         util.printout("[" .. tostring(method) .. " via curl] " .. redact_api_url(url) .. " ... ")
      end

      return json.decode(out)
   end

else -- use LuaSocket and LuaSec

   local warned_luasec = false

   api.Api.request = function(self: Api, url: string, params?: Parameters, post_params?: Parameters): {string : any}, string
      local server = tostring(self.config.server)
      local type Http = require("socket.http")
      local http_ok, http: boolean, Http
      local via = "luasocket"
      if server:match("^https://") then
         http_ok, http = pcall(require, "ssl.https") as (boolean, Http)
         if http_ok then
            via = "luasec"
         else
            if not warned_luasec then
               util.printerr("LuaSec is not available; using plain HTTP. Install 'luasec' to enable HTTPS.")
               warned_luasec = true
            end
            http_ok, http = pcall(require, "socket.http")
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
      local body: string
      local headers: {string: string} = {}
      if params and next(params) then
         url = url .. ("?" .. encode_query_string(params))
      end
      if post_params then
         local boundary: string
         body, boundary = multipart.encode(post_params)
         headers["Content-length"] = tostring(#body)
         headers["Content-type"] = "multipart/form-data; boundary=" .. tostring(boundary)
      end
      local method = post_params and "POST" or "GET"
      if self.debug then
         util.printout("[" .. tostring(method) .. " via "..via.."] " .. redact_api_url(url) .. " ... ")
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
      local pok, ret = pcall(json.decode, table.concat(out))
      if pok and ret then
         return ret
      end
      return nil, "API returned " .. tostring(status) .. " - " .. redact_api_url(url)
   end

end

function api.new(args: Args): Api, string
   local self: Api = {}
   setmetatable(self, { __index = Api })
   self.config = self:load_config() or {}
   self.config.server = args.server or self.config.server or cfg.upload.server
   self.config.version = self.config.version or cfg.upload.version
   self.config.key = args.temp_key or args.api_key or self.config.key
   self.debug = args.debug
   if not self.config.key then
      return nil, "You need an API key to upload rocks.\n" ..
                  "Navigate to "..self.config.server.."/settings to get a key\n" ..
                  "and then pass it through the --api-key=<key> flag."
   end
   if args.api_key then
      local ok, err = self:save_config()
      if not ok then
         return nil, err
      end
   end
   return self
end

return api
