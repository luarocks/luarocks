local deplocks = {}

local record DepsTable
   dependencies: {string: string}
   build_dependencies: {string: string}
   test_dependencies: {string: string}
end

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local persist = require("luarocks.persist")

local type DepsKey = require("luarocks.core.types.depskey").DepsKey
local type PersistableTable = require("luarocks.core.types.persist").PersistableTable

local depstable: DepsTable = {}
local depstable_mode = "start"
local deplock_abs_filename: string
local deplock_root_rock_name: string

function deplocks.init(root_rock_name: string, dirname: string)
   if depstable_mode ~= "start" then
      return
   end
   depstable_mode = "create"

   local filename = dir.path(dirname, "luarocks.lock")
   deplock_abs_filename = fs.absolute_name(filename)
   deplock_root_rock_name = root_rock_name

   depstable = {}
end

function deplocks.get_abs_filename(root_rock_name: string): string
   if root_rock_name == deplock_root_rock_name then
      return deplock_abs_filename
   end
end

function deplocks.load(root_rock_name: string, dirname: string): boolean, string, string
   if depstable_mode ~= "start" then
      return true, nil
   end
   depstable_mode = "locked"

   local filename = dir.path(dirname, "luarocks.lock")
   local _, result, errcode = persist.run_file(filename, {})
   if errcode == "load" or errcode == "run" then
      -- bad config file or depends on env, so error out
      return nil, nil, "Could not read existing lockfile " .. filename
   end

   if errcode == "open" then
      -- could not open, maybe file does not exist
      return true, nil
   end

   deplock_abs_filename = fs.absolute_name(filename)
   deplock_root_rock_name = root_rock_name

   -- FIXME we're not really checking that the table is a DepsTable
   depstable = result as DepsTable
   return true, filename
end

function deplocks.add(depskey: DepsKey, name: string, version: string)
   if depstable_mode == "locked" then
      return
   end

   local dk = depstable[depskey]
   if not dk then
      dk = {}
      depstable[depskey] = dk
   end

   if dk is {string: string} and not dk[name] then
      dk[name] = version
   end
end

function deplocks.get(depskey: DepsKey, name: string): string
   local dk = depstable[depskey]
   if dk is {string: string} then
      return dk[name]
   end
   return nil
end

function deplocks.write_file(): boolean, string
   if depstable_mode ~= "create" then
      return true
   end

   return persist.save_as_module(deplock_abs_filename, depstable as PersistableTable)
end

-- a table-like interface to deplocks
function deplocks.proxy(depskey: DepsKey): {string: string}
   return setmetatable({}, {
      __index = function(_, k: string): string
         return deplocks.get(depskey, k)
      end,
      __newindex = function(_, k: string, v: string)
         return deplocks.add(depskey, k, v)
      end,
   })
end

function deplocks.each(depskey: DepsKey): function(): string, string
   return util.sortedpairs(depstable[depskey] or {})
end

return deplocks
