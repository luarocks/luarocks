
--- Assorted utilities for managing tables, plus a scheduler for rollback functions.
-- Does not requires modules directly (only as locals
-- inside specific functions) to avoid interdependencies,
-- as this is used in the bootstrapping stage of luarocks.core.cfg.

local util = {}

local core = require("luarocks.core.util")

util.popen_read = core.popen_read
util.cleanup_path = core.cleanup_path
util.split_string = core.split_string
util.keys = core.keys
util.printerr = core.printerr
util.sortedpairs = core.sortedpairs
util.warning = core.warning

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
   ["dev"] = true,
   ["force"] = true,
   ["force-fast"] = true,
   ["from"] = "<server>",
   ["help"] = true,
   ["home"] = true,
   ["homepage"] = "\"<url>\"",
   ["issues"] = true,
   ["keep"] = true,
   ["labels"] = true,
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
   ["namespace"] = "<namespace>",
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
   ["temp-key"] = "<key>",
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
   
   local cfg = require("luarocks.core.cfg")
   
   if not tbl then return end
   
   if tbl.platforms then
      for _, platform in ipairs(cfg.platforms) do
         local platform_tbl = tbl.platforms[platform]
         if platform_tbl then
            core.deep_merge(tbl, platform_tbl)
         end
      end
   end
   tbl.platforms = nil
end

local var_format_pattern = "%$%((%a[%a%d_]+)%)"

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
   needed_set = core.make_shallow_copy(needed_set)
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
   local cfg = require("luarocks.core.cfg")
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
   local cfg = require("luarocks.core.cfg")
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
   local vers = require("luarocks.core.vers")

   if fs.is_dir(subdir) then
      for file in fs.dir(subdir) do
         file = dir.path(subdir, file)

         if file:match("rockspec$") and fs.is_file(file) then
            local rock, version = path.parse_name(file)

            if rock then
               if not versions[rock] or vers.compare_versions(version, versions[rock]) then
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

-- Quote Lua string, analogous to fs.Q.
-- @param s A string, such as "hello"
-- @return string: A quoted string, such as '"hello"'
function util.LQ(s)
   return ("%q"):format(s)
end

--- Normalize the --namespace flag and the user/rock syntax for namespaces.
-- If a namespace is given in user/rock syntax, update the --namespace flag;
-- If a namespace is given in --namespace flag, update the user/rock syntax.
-- In case of conflicts, the user/rock syntax takes precedence.
function util.adjust_name_and_namespace(name, flags)
   assert(type(name) == "string" or not name)
   assert(type(flags) == "table")

   if not name then
      return
   elseif name:match("%.rockspec$") or name:match("%.rock$") then
      return name
   end

   local namespace
   name, namespace = util.split_namespace(name)
   if namespace then
      flags["namespace"] = namespace
   end
   if flags["namespace"] then
      name = flags["namespace"] .. "/" .. name
   end
   return name:lower()
end

-- Split name and namespace of a package name.
-- @param name a name that may be in "namespace/name" format
-- @return string, string? - name and optionally a namespace
function util.split_namespace(name)
   local p1, p2 = name:match("^([^/]+)/([^/]+)$")
   if p1 then
      return p2, p1
   end
   return name
end

return util
