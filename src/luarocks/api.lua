--- API for addons.
local api = {}
package.loaded["luarocks.api"] = api

local fetch = require("luarocks.fetch")
local addon = require("luarocks.addon")
local fs = require("luarocks.fs")

function api.register_hook(name, callback)
   addon.register_hook(name, callback)
end

function api.register_rockspec_field(name, typetbl, callback)
   addon.register_rockspec_field(name, typetbl, callback)
end

function api.load_rockspec(filename, location)
   return fetch.load_rockspec(filename, location)
end

-- Expose everything in luarocks.fs except the verbose function.
for k, v in pairs(fs) do
   if k ~= "verbose" then
      api[k] = v
   end
end

return api
