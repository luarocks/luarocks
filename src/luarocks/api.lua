--- API for addons.
local api = {}
package.loaded["luarocks.api"] = api

local addon = require("luarocks.addon")

function api.register_hook(name, callback)
   addon.register_hook(name, callback)
end

function api.register_rockspec_field(name, typetbl, callback)
   addon.register_rockspec_field(name, typetbl, callback)
end

return api
