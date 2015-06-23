--- Registry for addons.
local addon = {}
package.loaded["luarocks.addon"] = addon

local type_check = require("luarocks.type_check")

local available_hooks = {
   "build.before", "build.after"
}
local hook_registry
local rockspec_field_registry

--- Reset the addon registries.
function addon.reset()
   hook_registry = {}
   for i, h in ipairs(available_hooks) do
      hook_registry[h] = {}
   end
   rockspec_field_registry = {}
   type_check.reset_rockspec_types()
end

addon.reset()

function addon.register_hook(name, callback)
   if not hook_registry[name] then
      return nil, "No hook called "..name
   end
   hook_registry[name][#hook_registry[name]+1] = callback
end

function addon.trigger_hook(name, ...)
   if not hook_registry[name] then
      return nil, "No hook called "..name
   end
   for i, cb in ipairs(hook_registry[name]) do
      cb(...)
   end
end

function addon.register_rockspec_field(name, typetbl, callback)
   if rockspec_field_registry[name] then
      return nil, "Rockspec field "..name.." already registered"
   end
   rockspec_field_registry[name] = {callback = callback}
   return type_check.add_rockspec_field(name, typetbl)
end

local function get(tbl, field)
   if tbl == nil then
      return nil
   end
   local i = field:find("%.")
   if i then
      return get(tbl[field:sub(1,i-1)], field:sub(i+1))
   end
   return tbl[field]
end

function addon.handle_rockspec(rockspec)
   for k, v in pairs(rockspec_field_registry) do
      if v.callback then
         field_value = get(rockspec, k)
         if field_value then
            v.callback(field_value)
         end
      end
   end
end

return addon
