--- API for addons.
local api = {}
package.loaded["luarocks.api"] = api

local function expose(modname, ...)
   local mod = require("luarocks."..modname)
   for i, k in ipairs({...}) do
      api[k] = mod[k]
   end
end

expose("fetch", "load_rockspec")
expose("addon", "register_hook", "register_rockspec_field")
expose("fs",
   "is_writable", "make_temp_dir", "execute", "execute_quiet", "list_dir",
   "exists")
expose("deps",
   "parse_version", "compare_versions", "parse_constraints", "parse_dep",
   "show_version", "show_dep", "match_constraints")

return api
