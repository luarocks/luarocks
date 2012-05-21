
--- Assorted utilities for managing tables, plus a scheduler for rollback functions.
-- Does not requires modules directly (only as locals
-- inside specific functions) to avoid interdependencies,
-- as this is used in the bootstrapping stage of luarocks.cfg.

local global_env = _G

module("luarocks.util", package.seeall)

local scheduled_functions = {}

--- Schedule a function to be executed upon program termination.
-- This is useful for actions such as deleting temporary directories
-- or failure rollbacks.
-- @param f function: Function to be executed.
-- @param ... arguments to be passed to function.
-- @return table: A token representing the scheduled execution,
-- which can be used to remove the item later from the list.
function schedule_function(f, ...)
   assert(type(f) == "function")
   
   local item = { fn = f, args = {...} }
   table.insert(scheduled_functions, item)
   return item
end

--- Unschedule a function.
-- This is useful for cancelling a rollback of a completed operation.
-- @param item table: The token representing the scheduled function that was
-- returned from the schedule_function call.
function remove_scheduled_function(item)
   for k, v in pairs(scheduled_functions) do
      if v == item then
         table.remove(scheduled_functions, k)
         return
      end
   end
end

--- Execute scheduled functions.
-- Some calls create temporary files and/or directories and register
-- corresponding cleanup functions. Calling this function will run
-- these function, erasing temporaries.
-- Functions are executed in the inverse order they were scheduled.
function run_scheduled_functions()
   local fs = require("luarocks.fs")
   fs.change_dir_to_root()
   for i = #scheduled_functions, 1, -1 do
      local item = scheduled_functions[i]
      item.fn(unpack(item.args))
   end
end

--- Extract flags from an arguments list.
-- Given string arguments, extract flag arguments into a flags set.
-- For example, given "foo", "--tux=beep", "--bla", "bar", "--baz",
-- it would return the following:
-- {["bla"] = true, ["tux"] = "beep", ["baz"] = true}, "foo", "bar".
function parse_flags(...)
   local args = {...}
   local flags = {}
   for i = #args, 1, -1 do
      local flag = args[i]:match("^%-%-(.*)")
      if flag then
         local var,val = flag:match("([a-z_%-]*)=(.*)")
         if val then
            flags[var] = val
         else
            flags[flag] = true
         end
         table.remove(args, i)
      end
   end
   return flags, unpack(args)
end

--- Merges contents of src on top of dst's contents.
-- @param dst Destination table, which will receive src's contents.
-- @param src Table which provides new contents to dst.
-- @see platform_overrides
function deep_merge(dst, src)
   for k, v in pairs(src) do
      if type(v) == "table" then
         if not dst[k] then
            dst[k] = {}
         end
         if type(dst[k]) == "table" then
            deep_merge(dst[k], v)
         else
            dst[k] = v
         end
      else
         dst[k] = v
      end
   end
end

--- Perform platform-specific overrides on a table.
-- Overrides values of table with the contents of the appropriate
-- subset of its "platforms" field. The "platforms" field should
-- be a table containing subtables keyed with strings representing
-- platform names. Names that match the contents of the global
-- cfg.platforms setting are used. For example, if
-- cfg.platforms= {"foo"}, then the fields of
-- tbl.platforms.foo will overwrite those of tbl with the same
-- names. For table values, the operation is performed recursively
-- (tbl.platforms.foo.x.y.z overrides tbl.x.y.z; other contents of
-- tbl.x are preserved).
-- @param tbl table or nil: Table which may contain a "platforms" field;
-- if it doesn't (or if nil is passed), this function does nothing.
function platform_overrides(tbl)
   assert(type(tbl) == "table" or not tbl)
   
   local cfg = require("luarocks.cfg")
   
   if not tbl then return end
   
   if tbl.platforms then
      for _, platform in ipairs(cfg.platforms) do
         local platform_tbl = tbl.platforms[platform]
         if platform_tbl then
            deep_merge(tbl, platform_tbl)
         end
      end
   end
   tbl.platforms = nil
end

local var_format_pattern = "%$%((%a[%a%d_]+)%)"

--- Create a new shallow copy of a table: a new table with
-- the same keys and values. Keys point to the same objects as
-- the original table (ie, does not copy recursively).
-- @param tbl table: the input table
-- @return table: a new table with the same contents.
local function make_shallow_copy(tbl)
   local copy = {}
   for k,v in pairs(tbl) do
      copy[k] = v
   end
   return copy
end

-- Check if a set of needed variables are referenced
-- somewhere in a list of definitions, warning the user
-- about any unused ones. Each key in needed_set should
-- appear as a $(XYZ) variable at least once as a
-- substring of some value of var_defs.
-- @param var_defs: a table with string keys and string
-- values, containing variable definitions.
-- @param needed_set: a set where keys are the names of
-- needed variables.
-- @param msg string: the warning message to display.
function warn_if_not_used(var_defs, needed_set, msg)
   needed_set = make_shallow_copy(needed_set)
   for var,val in pairs(var_defs) do
      for used in val:gmatch(var_format_pattern) do
         needed_set[used] = nil
      end
   end
   for var,_ in pairs(needed_set) do
      warning(msg:format(var))
   end
end

-- Output any entries that might remain in $(XYZ) format,
-- warning the user that substitutions have failed.
-- @param line string: the input string
local function warn_failed_matches(line)
   local any_failed = false
   if line:match(var_format_pattern) then
      for unmatched in line:gmatch(var_format_pattern) do
         warning("unmatched variable " .. unmatched)
         any_failed = true
      end
   end
   return any_failed
end

--- Perform make-style variable substitutions on string values of a table.
-- For every string value tbl.x which contains a substring of the format
-- "$(XYZ)" will have this substring replaced by vars["XYZ"], if that field
-- exists in vars. Only string values are processed; this function
-- does not scan subtables recursively.
-- @param tbl table: Table to have its string values modified.
-- @param vars table: Table containing string-string key-value pairs 
-- representing variables to replace in the strings values of tbl.
function variable_substitutions(tbl, vars)
   assert(type(tbl) == "table")
   assert(type(vars) == "table")
   
   local updated = {}
   for k, v in pairs(tbl) do
      if type(v) == "string" then
         updated[k] = v:gsub(var_format_pattern, vars)
         if warn_failed_matches(updated[k]) then
            updated[k] = updated[k]:gsub(var_format_pattern, "")
         end
      end
   end
   for k, v in pairs(updated) do
      tbl[k] = v
   end
end

--- Return an array of keys of a table.
-- @param tbl table: The input table.
-- @return table: The array of keys.
function keys(tbl)
   local ks = {}
   for k,_ in pairs(tbl) do
      table.insert(ks, k)
   end
   return ks
end

local function default_sort(a, b)
   local ta = type(a)
   local tb = type(b)
   if ta == "number" and tb == "number" then
      return a < b
   elseif ta == "number" then
      return true
   elseif tb == "number" then
      return false
   else
      return tostring(a) < tostring(b)
   end
end

-- The iterator function used internally by util.sortedpairs.
-- @param tbl table: The table to be iterated.
-- @param sort_function function or nil: An optional comparison function
-- to be used by table.sort when sorting keys.
-- @see sortedpairs
local function sortedpairs_iterator(tbl, sort_function)
   local ks = keys(tbl)
   if not sort_function or type(sort_function) == "function" then
      table.sort(ks, sort_function or default_sort)
      for _, k in ipairs(ks) do
         coroutine.yield(k, tbl[k])
      end
   else
      local order = sort_function
      local done = {}
      for _, k in ipairs(order) do
         local sub_order
         if type(k) == "table" then
            sub_order = k[2]
            k = k[1]
         end
         if tbl[k] then
            done[k] = true
            coroutine.yield(k, tbl[k], sub_order)
         end
      end
      table.sort(ks, default_sort)
      for _, k in ipairs(ks) do
         if not done[k] then
            coroutine.yield(k, tbl[k])
         end
      end
   end
end

--- A table iterator generator that returns elements sorted by key,
-- to be used in "for" loops.
-- @param tbl table: The table to be iterated.
-- @param sort_function function or table or nil: An optional comparison function
-- to be used by table.sort when sorting keys, or an array listing an explicit order
-- for keys. If a value itself is an array, it is taken so that the first element
-- is a string representing the field name, and the second element is a priority table
-- for that key.
-- @return function: the iterator function.
function sortedpairs(tbl, sort_function)
   return coroutine.wrap(function() sortedpairs_iterator(tbl, sort_function) end)
end

function starts_with(s, prefix)
   return s:sub(1,#prefix) == prefix
end

--- Print a line to standard output
function printout(...)
   io.stdout:write(table.concat({...},"\t"))
   io.stdout:write("\n")
end

--- Print a line to standard error
function printerr(...)
   io.stderr:write(table.concat({...},"\t"))
   io.stderr:write("\n")
end

--- Display a warning message.
-- @param msg string: the warning message
function warning(msg)
   printerr("Warning: "..msg)
end

-- from http://lua-users.org/wiki/SplitJoin
-- by PhilippeLhoste
function split_string(str, delim, maxNb)
   -- Eliminate bad cases...
   if string.find(str, delim) == nil then
      return { str }
   end
   if maxNb == nil or maxNb < 1 then
      maxNb = 0    -- No limit
   end
   local result = {}
   local pat = "(.-)" .. delim .. "()"
   local nb = 0
   local lastPos
   for part, pos in string.gmatch(str, pat) do
      nb = nb + 1
      result[nb] = part
      lastPos = pos
      if nb == maxNb then break end
   end
   -- Handle the last field
   if nb ~= maxNb then
      result[nb + 1] = string.sub(str, lastPos)
   end
   return result
end

--[[
Author: Julio Manuel Fernandez-Diaz
Date:   January 12, 2007
(For Lua 5.1)

Formats tables with cycles recursively to any depth.
The output is returned as a string.
References to other tables are shown as values.
Self references are indicated.

The string returned is "Lua code", which can be procesed
(in the case in which indent is composed by spaces or "--").
Userdata and function keys and values are shown as strings,
which logically are exactly not equivalent to the original code.

This routine can serve for pretty formating tables with
proper indentations, apart from printing them:

io.write(table.show(t, "t"))   -- a typical use

Heavily based on "Saving tables with cycles", PIL2, p. 113.

Arguments:
t is the table.
name is the name of the table (optional)
indent is a first indentation (optional).
--]]
function show_table(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   local function isemptytable(t) return next(t) == nil end
   
   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return ("%q"):format(so .. ", C function")
         else 
            -- the information is defined through lines
            return ("%q"):format(so .. ", defined in (" .. info.linedefined .. "-" .. info.lastlinedefined .. ")" .. info.source)
         end
      elseif type(o) == "number" then
         return so
      else
         return ("%q"):format(so)
      end
   end
   
   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name
      
      cart = cart .. indent .. field
      
      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = ("%s[%s]"):format(name, k)
                  field = ("[%s]"):format(k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end
   
   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end
