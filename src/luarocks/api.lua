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

local fs_exposure = {
   "is_writable", "make_temp_dir", "execute", "execute_quiet", "list_dir",
   "exists"
}
for i, k in ipairs(fs_exposure) do
   api[k] = fs[k]
end

return api
