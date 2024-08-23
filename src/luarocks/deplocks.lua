local deplocks = {}







local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local persist = require("luarocks.persist")




local depstable = {}
local depstable_mode = "start"
local deplock_abs_filename
local deplock_root_rock_name

function deplocks.init(root_rock_name, dirname)
   if depstable_mode ~= "start" then
      return
   end
   depstable_mode = "create"

   local filename = dir.path(dirname, "luarocks.lock")
   deplock_abs_filename = fs.absolute_name(filename)
   deplock_root_rock_name = root_rock_name

   depstable = {}
end

function deplocks.get_abs_filename(root_rock_name)
   if root_rock_name == deplock_root_rock_name then
      return deplock_abs_filename
   end
end

function deplocks.load(root_rock_name, dirname)
   if depstable_mode ~= "start" then
      return true, nil
   end
   depstable_mode = "locked"

   local filename = dir.path(dirname, "luarocks.lock")
   local _, result, errcode = persist.run_file(filename, {})
   if errcode == "load" or errcode == "run" then

      return nil, nil, "Could not read existing lockfile " .. filename
   end

   if errcode == "open" then

      return true, nil
   end

   deplock_abs_filename = fs.absolute_name(filename)
   deplock_root_rock_name = root_rock_name


   depstable = result
   return true, filename
end

function deplocks.add(depskey, name, version)
   if depstable_mode == "locked" then
      return
   end

   local dk = depstable[depskey]
   if not dk then
      dk = {}
      depstable[depskey] = dk
   end

   if type(dk) == "table" and not dk[name] then
      dk[name] = version
   end
end

function deplocks.get(depskey, name)
   local dk = depstable[depskey]
   if type(dk) == "table" then
      return dk[name]
   end
   return nil
end

function deplocks.write_file()
   if depstable_mode ~= "create" then
      return true
   end

   return persist.save_as_module(deplock_abs_filename, depstable)
end


function deplocks.proxy(depskey)
   return setmetatable({}, {
      __index = function(_, k)
         return deplocks.get(depskey, k)
      end,
      __newindex = function(_, k, v)
         return deplocks.add(depskey, k, v)
      end,
   })
end

function deplocks.each(depskey)
   return util.sortedpairs(depstable[depskey] or {})
end

return deplocks
