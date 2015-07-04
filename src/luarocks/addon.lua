--- Registry for addons.
local addon = {}
package.loaded["luarocks.addon"] = addon

local type_check = require("luarocks.type_check")

local available_hooks = {
   "build.before", "build.after"
}
local hook_registry
local rockspec_field_registry

--- Make sure luarocks.api is loaded. Otherwise when using
-- pcall_with_restricted_require, require calls in luarocks.api itself will be
-- blocked. This is not what we want.
require("luarocks.api")

local original_require = require
--- Block require calls to luarocks modules except luarocks.api and
-- luarocks.addon.*. This is intended to prevent addon authors from
-- accidentally using the internal APIs and not as a real sandboxing
-- mechanism; it can be easily worked around by e.g. calling the package
-- searchers directly.
local function restricted_require(modname)
   if modname:sub(1, 9) == "luarocks." and modname ~= "luarocks.api" then
      local info = debug.getinfo(2, "Sl")
      error(string.format(
         "Attempting to require LuaRocks internal module %s: %s:%d. "..
         "Only use luarocks.api to access LuaRocks facilities.",
         modname, info.short_src, info.currentline))
   end
   return original_require(modname)
end

local function pcall_with_restricted_require(f, ...)
   require = restricted_require
   ret = {pcall(f, ...)}
   require = original_require
   return unpack(ret)
end

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
   for i, callback in ipairs(hook_registry[name]) do
      local ok, err = pcall_with_restricted_require(callback, ...)
      if not ok then
         -- TODO include the name of addon in the error message
         print("Addon hook for "..name.." failed: "..err)
      end
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
         local field_value = get(rockspec, k)
         if field_value then
            local ok, err = pcall_with_restricted_require(v.callback, field_value, rockspec)
            if not ok then
               -- TODO include the name of addon in the error message
               print("Addon callback for rockspec field "..k.." failed: "..err)
            end
         end
      end
   end
end

function addon.load(name)
   local modname = "luarocks.addon."..name
   package.loaded[modname] = nil
   local ok, err = pcall_with_restricted_require(require, modname)
   if not ok then
      return nil, err
   end
   local mod = err
   local ok, err = pcall_with_restricted_require(mod.load)
   if not ok then
      return nil, err
   end
   return true
end

return addon
