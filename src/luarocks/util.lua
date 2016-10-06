
--- Assorted utilities for managing tables, plus a scheduler for rollback functions.
-- Does not requires modules directly (only as locals
-- inside specific functions) to avoid interdependencies,
-- as this is used in the bootstrapping stage of luarocks.cfg.

local util = {}

local unpack = unpack or table.unpack

local scheduled_functions = {}
local debug = require("debug")

--- Schedule a function to be executed upon program termination.
-- This is useful for actions such as deleting temporary directories
-- or failure rollbacks.
-- @param f function: Function to be executed.
-- @param ... arguments to be passed to function.
-- @return table: A token representing the scheduled execution,
-- which can be used to remove the item later from the list.
function util.schedule_function(f, ...)
   assert(type(f) == "function")
   
   local item = { fn = f, args = {...} }
   table.insert(scheduled_functions, item)
   return item
end

--- Unschedule a function.
-- This is useful for cancelling a rollback of a completed operation.
-- @param item table: The token representing the scheduled function that was
-- returned from the schedule_function call.
function util.remove_scheduled_function(item)
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
function util.run_scheduled_functions()
   local fs = require("luarocks.fs")
   fs.change_dir_to_root()
   for i = #scheduled_functions, 1, -1 do
      local item = scheduled_functions[i]
      item.fn(unpack(item.args))
   end
end

--- Produce a Lua pattern that matches precisely the given string
-- (this is suitable to be concatenating to other patterns,
-- so it does not include beginning- and end-of-string markers (^$)
-- @param s string: The input string
-- @return string: The equivalent pattern
function util.matchquote(s)
   return (s:gsub("[?%-+*%[%].%%()$^]","%%%1"))
end

--- List of supported arguments.
-- Arguments that take no parameters are marked with the boolean true.
-- Arguments that take a parameter are marked with a descriptive string.
-- Arguments that may take an empty string are described in quotes,
-- (as in the value for --detailed="<text>").
-- For all other string values, it means the parameter is mandatory.
local supported_flags = {
   ["all"] = true,
   ["api-key"] = "<key>",
   ["append"] = true,
   ["arch"] = "<arch>",
   ["bin"] = true,
   ["binary"] = true,
   ["branch"] = "<branch-name>",
   ["debug"] = true,
   ["deps"] = true,
   ["deps-mode"] = "<mode>",
   ["detailed"] = "\"<text>\"",
   ["force"] = true,
   ["force-fast"] = true,
   ["from"] = "<server>",
   ["help"] = true,
   ["home"] = true,
   ["homepage"] = "\"<url>\"",
   ["keep"] = true,
   ["lib"] = "<library>",
   ["license"] = "\"<text>\"",
   ["list"] = true,
   ["local"] = true,
   ["local-tree"] = true,
   ["lr-bin"] = true,
   ["lr-cpath"] = true,
   ["lr-path"] = true,
   ["lua-version"] = "<vers>",
   ["lua-ver"] = true,
   ["lua-incdir"] = true,
   ["lua-libdir"] = true,
   ["modules"] = true,
   ["mversion"] = true,
   ["no-refresh"] = true,
   ["nodeps"] = true,
   ["old-versions"] = true,
   ["only-deps"] = true,
   ["only-from"] = "<server>",
   ["only-server"] = "<server>",
   ["only-sources"] = "<url>",
   ["only-sources-from"] = "<url>",
   ["outdated"] = true,
   ["output"] = "<file>",
   ["pack-binary-rock"] = true,
   ["porcelain"] = true,
   ["quick"] = true,
   ["rock-dir"] = true,
   ["rock-tree"] = true,
   ["rock-trees"] = true,
   ["rockspec"] = true,
   ["rockspec-format"] = "<ver>",
   ["server"] = "<server>",
   ["skip-pack"] = true,
   ["source"] = true,
   ["summary"] = "\"<text>\"",
   ["system-config"] = true,
   ["tag"] = "<tag>",
   ["timeout"] = "<seconds>",
   ["to"] = "<path>",
   ["tree"] = "<path>",
   ["user-config"] = true,
   ["verbose"] = true,
   ["version"] = true,
}

--- Extract flags from an arguments list.
-- Given string arguments, extract flag arguments into a flags set.
-- For example, given "foo", "--tux=beep", "--bla", "bar", "--baz",
-- it would return the following:
-- {["bla"] = true, ["tux"] = "beep", ["baz"] = true}, "foo", "bar".
function util.parse_flags(...)
   local args = {...}
   local flags = {}
   local i = 1
   local out = {}
   local ignore_flags = false
   while i <= #args do
      local flag = args[i]:match("^%-%-(.*)")
      if flag == "--" then
         ignore_flags = true
      end
      if flag and not ignore_flags then
         local var,val = flag:match("([a-z_%-]*)=(.*)")
         if val then
            local vartype = supported_flags[var]
            if type(vartype) == "string" then
               if val == "" and vartype:sub(1,1) ~= '"' then
                  return { ERROR = "Invalid argument: parameter to flag --"..var.."="..vartype.." cannot be empty." }
               end
               flags[var] = val
            else
               if vartype then
                  return { ERROR = "Invalid argument: flag --"..var.." does not take an parameter." }
               else
                  return { ERROR = "Invalid argument: unknown flag --"..var.."." }
               end
            end
         else
            local var = flag
            local vartype = supported_flags[var]
            if type(vartype) == "string" then
               i = i + 1
               local val = args[i]
               if not val then
                  return { ERROR = "Invalid argument: flag --"..var.."="..vartype.." expects a parameter." }
               end
               if val:match("^%-%-.*") then
                  return { ERROR = "Invalid argument: flag --"..var.."="..vartype.." expects a parameter (if you really want to pass "..val.." as an argument to --"..var..", use --"..var.."="..val..")." }
               else
                  if val == "" and vartype:sub(1,1) ~= '"' then
                     return { ERROR = "Invalid argument: parameter to flag --"..var.."="..vartype.." cannot be empty." }
                  end
                  flags[var] = val
               end
            elseif vartype == true then
               flags[var] = true
            else
               return { ERROR = "Invalid argument: unknown flag --"..var.."." }
            end
         end
      else
         table.insert(out, args[i])
      end
      i = i + 1
   end
   return flags, unpack(out)
end

-- Adds legacy 'run' function to a command module.
-- @param command table: command module with 'command' function,
-- the added 'run' function calls it after parseing command-line arguments.
function util.add_run_function(command)
   command.run = function(...) return command.command(util.parse_flags(...)) end
end

--- Merges contents of src on top of dst's contents.
-- @param dst Destination table, which will receive src's contents.
-- @param src Table which provides new contents to dst.
-- @see platform_overrides
function util.deep_merge(dst, src)
   for k, v in pairs(src) do
      if type(v) == "table" then
         if not dst[k] then
            dst[k] = {}
         end
         if type(dst[k]) == "table" then
            util.deep_merge(dst[k], v)
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
function util.platform_overrides(tbl)
   assert(type(tbl) == "table" or not tbl)
   
   local cfg = require("luarocks.cfg")
   
   if not tbl then return end
   
   if tbl.platforms then
      for _, platform in ipairs(cfg.platforms) do
         local platform_tbl = tbl.platforms[platform]
         if platform_tbl then
            util.deep_merge(tbl, platform_tbl)
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
function util.make_shallow_copy(tbl)
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
function util.warn_if_not_used(var_defs, needed_set, msg)
   needed_set = util.make_shallow_copy(needed_set)
   for _, val in pairs(var_defs) do
      for used in val:gmatch(var_format_pattern) do
         needed_set[used] = nil
      end
   end
   for var, _ in pairs(needed_set) do
      util.warning(msg:format(var))
   end
end

-- Output any entries that might remain in $(XYZ) format,
-- warning the user that substitutions have failed.
-- @param line string: the input string
local function warn_failed_matches(line)
   local any_failed = false
   if line:match(var_format_pattern) then
      for unmatched in line:gmatch(var_format_pattern) do
         util.warning("unmatched variable " .. unmatched)
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
function util.variable_substitutions(tbl, vars)
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
function util.keys(tbl)
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

--- A table iterator generator that returns elements sorted by key,
-- to be used in "for" loops.
-- @param tbl table: The table to be iterated.
-- @param sort_function function or table or nil: An optional comparison function
-- to be used by table.sort when sorting keys, or an array listing an explicit order
-- for keys. If a value itself is an array, it is taken so that the first element
-- is a string representing the field name, and the second element is a priority table
-- for that key, which is returned by the iterator as the third value after the key
-- and the value.
-- @return function: the iterator function.
function util.sortedpairs(tbl, sort_function)
   sort_function = sort_function or default_sort
   local keys = util.keys(tbl)
   local sub_orders = {}

   if type(sort_function) == "function" then
      table.sort(keys, sort_function)
   else
      local order = sort_function
      local ordered_keys = {}
      local all_keys = keys
      keys = {}

      for _, order_entry in ipairs(order) do
         local key, sub_order
         if type(order_entry) == "table" then
            key = order_entry[1]
            sub_order = order_entry[2]
         else
            key = order_entry
         end

         if tbl[key] then
            ordered_keys[key] = true
            sub_orders[key] = sub_order
            table.insert(keys, key)
         end
      end

      table.sort(all_keys, default_sort)
      for _, key in ipairs(all_keys) do
         if not ordered_keys[key] then
            table.insert(keys, key)
         end
      end
   end

   local i = 1
   return function()
      local key = keys[i]
      i = i + 1
      return key, tbl[key], sub_orders[key]
   end
end

function util.lua_versions()
   local versions = { "5.1", "5.2", "5.3" }
   local i = 0
   return function()
      i = i + 1
      return versions[i]
   end
end

function util.starts_with(s, prefix)
   return s:sub(1,#prefix) == prefix
end

--- Print a line to standard output
function util.printout(...)
   io.stdout:write(table.concat({...},"\t"))
   io.stdout:write("\n")
end

--- Print a line to standard error
function util.printerr(...)
   io.stderr:write(table.concat({...},"\t"))
   io.stderr:write("\n")
end

--- Display a warning message.
-- @param msg string: the warning message
function util.warning(msg)
   util.printerr("Warning: "..msg)
end

function util.title(msg, porcelain, underline)
   if porcelain then return end
   util.printout()
   util.printout(msg)
   util.printout((underline or "-"):rep(#msg))
   util.printout()
end

function util.this_program(default)
   local i = 1
   local last, cur = default, default
   while i do
      local dbg = debug.getinfo(i,"S")
      if not dbg then break end
      last = cur
      cur = dbg.source
      i=i+1
   end
   return last:sub(2)
end

function util.deps_mode_help(program)
   local cfg = require("luarocks.cfg")
   return [[
--deps-mode=<mode>  How to handle dependencies. Four modes are supported:
                    * all - use all trees from the rocks_trees list
                      for finding dependencies
                    * one - use only the current tree (possibly set
                      with --tree)
                    * order - use trees based on order (use the current
                      tree and all trees below it on the rocks_trees list)
                    * none - ignore dependencies altogether.
                    The default mode may be set with the deps_mode entry
                    in the configuration file.
                    The current default is "]]..cfg.deps_mode..[[".
                    Type ']]..util.this_program(program or "luarocks")..[[' with no arguments to see
                    your list of rocks trees.
]]
end

function util.see_help(command, program)
   return "See '"..util.this_program(program or "luarocks")..' help'..(command and " "..command or "").."'."
end

function util.announce_install(rockspec)
   local cfg = require("luarocks.cfg")
   local path = require("luarocks.path")

   local suffix = ""
   if rockspec.description and rockspec.description.license then
      suffix = " (license: "..rockspec.description.license..")"
   end

   local root_dir = path.root_dir(cfg.rocks_dir)
   util.printout(rockspec.name.." "..rockspec.version.." is now installed in "..root_dir..suffix)
   util.printout()
end

--- Collect rockspecs located in a subdirectory.
-- @param versions table: A table mapping rock names to newest rockspec versions.
-- @param paths table: A table mapping rock names to newest rockspec paths.
-- @param unnamed_paths table: An array of rockspec paths that don't contain rock
-- name and version in regular format.
-- @param subdir string: path to subdirectory.
local function collect_rockspecs(versions, paths, unnamed_paths, subdir)
   local fs = require("luarocks.fs")
   local dir = require("luarocks.dir")
   local path = require("luarocks.path")
   local deps = require("luarocks.deps")

   if fs.is_dir(subdir) then
      for file in fs.dir(subdir) do
         file = dir.path(subdir, file)

         if file:match("rockspec$") and fs.is_file(file) then
            local rock, version = path.parse_name(file)

            if rock then
               if not versions[rock] or deps.compare_versions(version, versions[rock]) then
                  versions[rock] = version
                  paths[rock] = file
               end
            else
               table.insert(unnamed_paths, file)
            end
         end
      end
   end
end

--- Get default rockspec name for commands that take optional rockspec name.
-- @return string or (nil, string): path to the rockspec or nil and error message.
function util.get_default_rockspec()
   local versions, paths, unnamed_paths = {}, {}, {}
   -- Look for rockspecs in some common locations.
   collect_rockspecs(versions, paths, unnamed_paths, ".")
   collect_rockspecs(versions, paths, unnamed_paths, "rockspec")
   collect_rockspecs(versions, paths, unnamed_paths, "rockspecs")

   if #unnamed_paths > 0 then
      -- There are rockspecs not following "name-version.rockspec" format.
      -- More than one are ambiguous.
      if #unnamed_paths > 1 then
         return nil, "Please specify which rockspec file to use."
      else
         return unnamed_paths[1]
      end
   else
      local rock = next(versions)

      if rock then
         -- If there are rockspecs for multiple rocks it's ambiguous.
         if next(versions, rock) then
            return nil, "Please specify which rockspec file to use."
         else
            return paths[rock]
         end
      else
         return nil, "Argument missing: please specify a rockspec to use on current directory."
      end
   end
end

-- from http://lua-users.org/wiki/SplitJoin
-- by PhilippeLhoste
function util.split_string(str, delim, maxNb)
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

--- Remove repeated entries from a path-style string.
-- Example: given ("a;b;c;a;b;d", ";"), returns "a;b;c;d".
-- @param list string: A path string (from $PATH or package.path)
-- @param sep string: The separator
function util.remove_path_dupes(list, sep)
   assert(type(list) == "string")
   assert(type(sep) == "string")
   local parts = util.split_string(list, sep)
   local final, entries = {}, {}
   for _, part in ipairs(parts) do
      part = part:gsub("//", "/")
      if not entries[part] then
         table.insert(final, part)
         entries[part] = true
      end
   end
   return table.concat(final, sep)
end

---
-- Formats tables with cycles recursively to any depth.
-- References to other tables are shown as values.
-- Self references are indicated.
-- The string returned is "Lua code", which can be procesed
-- (in the case in which indent is composed by spaces or "--").
-- Userdata and function keys and values are shown as strings,
-- which logically are exactly not equivalent to the original code.
-- This routine can serve for pretty formating tables with
-- proper indentations, apart from printing them:
-- io.write(table.show(t, "t"))   -- a typical use
-- Written by Julio Manuel Fernandez-Diaz,
-- Heavily based on "Saving tables with cycles", PIL2, p. 113.
-- @param t table: is the table.
-- @param name string: is the name of the table (optional)
-- @param indent string: is a first indentation (optional).
-- @return string: the pretty-printed table
function util.show_table(t, name, indent)
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

function util.array_contains(tbl, value)
   for _, v in ipairs(tbl) do
      if v == value then
         return true
      end
   end
   return false
end

-- Quote Lua string, analogous to fs.Q.
-- @param s A string, such as "hello"
-- @return string: A quoted string, such as '"hello"'
function util.LQ(s)
   return ("%q"):format(s)
end

return util
