
--- Assorted utilities for managing tables, plus a scheduler for rollback functions.
-- Does not requires modules directly (only as locals
-- inside specific functions) to avoid interdependencies,
-- as this is used in the bootstrapping stage of luarocks.core.cfg.

local util = {}

local core = require("luarocks.core.util")

util.cleanup_path = core.cleanup_path
util.split_string = core.split_string
util.sortedpairs = core.sortedpairs
util.deep_merge = core.deep_merge
util.deep_merge_under = core.deep_merge_under
util.popen_read = core.popen_read
util.show_table = core.show_table
util.printerr = core.printerr
util.warning = core.warning
util.keys = core.keys

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
   if fs.change_dir_to_root then
      fs.change_dir_to_root()
   end
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
   ["build-deps"] = true,
   ["debug"] = true,
   ["deps"] = true,
   ["deps-mode"] = "<mode>",
   ["detailed"] = "\"<text>\"",
   ["dev"] = true,
   ["force"] = true,
   ["force-fast"] = true,
   ["from"] = "<server>",
   ["global"] = true,
   ["help"] = true,
   ["home"] = true,
   ["homepage"] = "\"<url>\"",
   ["index"] = true,
   ["issues"] = true,
   ["json"] = true,
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
   ["lua-dir"] = "<path>",
   ["lua-version"] = "<vers>",
   ["lua-versions"] = "<versions>",
   ["lua-ver"] = true,
   ["lua-incdir"] = true,
   ["lua-libdir"] = true,
   ["modules"] = true,
   ["mversion"] = true,
   ["namespace"] = "<namespace>",
   ["no-bin"] = true,
   ["no-doc"] = true,
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
   ["project-tree"] = "<tree>",
   ["quick"] = true,
   ["reset"] = true,
   ["rock-dir"] = true,
   ["rock-license"] = true,
   ["rock-namespace"] = true,
   ["rock-tree"] = true,
   ["rock-trees"] = true,
   ["rockspec"] = true,
   ["rockspec-format"] = "<ver>",
   ["scope"] = "<system|user|project>",
   ["server"] = "<server>",
   ["sign"] = true,
   ["skip-pack"] = true,
   ["source"] = true,
   ["summary"] = "\"<text>\"",
   ["system-config"] = true,
   ["tag"] = "<tag>",
   ["test-type"] = "<type>",
   ["temp-key"] = "<key>",
   ["timeout"] = "<seconds>",
   ["to"] = "<path>",
   ["tree"] = "<path>",
   ["unset"] = true,
   ["user-config"] = true,
   ["verbose"] = true,
   ["verify"] = true,
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
   local state = "initial"
   while i <= #args do
      local flag = args[i]:match("^%-%-(.*)")
      if state == "initial" and flag == "" then
         state = "ignore_flags"
      elseif state == "initial" and flag then
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
      elseif state == "ignore_flags" or (state == "initial" and not flag) then
         table.insert(out, args[i])
      end
      i = i + 1
   end
   return flags, unpack(out)
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

function util.lua_versions(sort)
   local versions = { "5.1", "5.2", "5.3", "5.4" }
   local i = 0
   if sort == "descending" then
      i = #versions + 1
      return function()
         i = i - 1
         return versions[i]
      end
   else
      return function()
         i = i + 1
         return versions[i]
      end
   end
end

function util.lua_path_variables()
   local cfg = require("luarocks.core.cfg")
   local lpath_var = "LUA_PATH"
   local lcpath_var = "LUA_CPATH"

   local lv = cfg.lua_version:gsub("%.", "_")
   if lv ~= "5_1" then
      if os.getenv("LUA_PATH_" .. lv) then
         lpath_var = "LUA_PATH_" .. lv
      end
      if os.getenv("LUA_CPATH_" .. lv) then
         lcpath_var = "LUA_CPATH_" .. lv
      end
   end
   return lpath_var, lcpath_var
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
   local prog = last:sub(1,1) == "@" and last:sub(2) or last

   -- Check if we found the true path of a script that has a wrapper
   local lrdir, binpath = prog:match("^(.*)/lib/luarocks/rocks%-[0-9.]*/[^/]+/[^/]+(/bin/[^/]+)$")
   if lrdir then
      -- Return the wrapper instead
      return lrdir .. binpath
   end

   return prog
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

   util.printout(rockspec.name.." "..rockspec.version.." is now installed in "..path.root_dir(cfg.root_dir)..suffix)
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
      local fs = require("luarocks.fs")
      local dir = require("luarocks.dir")
      local basename = dir.base_name(fs.current_dir())

      if paths[basename] then
         return paths[basename]
      end

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
function util.adjust_name_and_namespace(ns_name, flags)
   assert(type(ns_name) == "string" or not ns_name)
   assert(type(flags) == "table")

   if not ns_name then
      return
   elseif ns_name:match("%.rockspec$") or ns_name:match("%.rock$") then
      return ns_name
   end

   local name, namespace = util.split_namespace(ns_name)
   if namespace then
      flags["namespace"] = namespace
   end
   if flags["namespace"] then
      name = flags["namespace"] .. "/" .. name
   end
   return name:lower()
end

-- Split name and namespace of a package name.
-- @param ns_name a name that may be in "namespace/name" format
-- @return string, string? - name and optionally a namespace
function util.split_namespace(ns_name)
   local p1, p2 = ns_name:match("^([^/]+)/([^/]+)$")
   if p1 then
      return p2, p1
   end
   return ns_name
end

function util.deep_copy(tbl)
   local copy = {}
   for k, v in pairs(tbl) do
      if type(v) == "table" then
         copy[k] = util.deep_copy(v)
      else
         copy[k] = v
      end
   end
   return copy
end

-- An ode to the multitude of JSON libraries out there...
function util.require_json()
   local list = { "cjson", "dkjson", "json" }
   for _, lib in ipairs(list) do
      local json_ok, json = pcall(require, lib)
      if json_ok then
         pcall(json.use_lpeg) -- optional feature in dkjson
         return json_ok, json
      end
   end
   local errmsg = "Failed loading "
   for i, name in ipairs(list) do
      if i == #list then
         errmsg = errmsg .."and '"..name.."'. Use 'luarocks search <partial-name>' to search for a library and 'luarocks install <name>' to install one."
      else
         errmsg = errmsg .."'"..name.."', "
      end
   end
   return nil, errmsg
end

-- A portable version of fs.exists that can be used at early startup,
-- before the platform has been determined and luarocks.fs has been
-- initialized.
function util.exists(file)
   local fd, _, code = io.open(file, "r")
   if code == 13 then
      -- code 13 means "Permission denied" on both Unix and Windows
      -- io.open on folders always fails with code 13 on Windows
      return true
   end
   if fd then
      fd:close()
      return true
   end
   return false
end

do
   local function Q(pathname)
      if pathname:match("^.:") then
         return pathname:sub(1, 2) .. '"' .. pathname:sub(3) .. '"'
      end
      return '"' .. pathname .. '"'
   end

   function util.check_lua_version(lua_exe, luaver)
      if not util.exists(lua_exe) then
         return nil
      end
      local lv, err = util.popen_read(Q(lua_exe) .. ' -e "io.write(_VERSION:sub(5))"')
      if luaver and luaver ~= lv then
         return nil
      end
      local ljv
      if lv == "5.1" then
         ljv = util.popen_read(Q(lua_exe) .. ' -e "io.write(tostring(jit and jit.version:sub(8)))"')
         if ljv == "nil" then
            ljv = nil
         end
      end
      return lv, ljv
   end

   local find_lua_bindir
   do
      local exe_suffix = (package.config:sub(1, 1) == "\\" and ".exe" or "")

      local function insert_lua_variants(names, luaver)
         local variants = {
            "lua" .. luaver .. exe_suffix,
            "lua" .. luaver:gsub("%.", "") .. exe_suffix,
            "lua-" .. luaver .. exe_suffix,
            "lua-" .. luaver:gsub("%.", "") .. exe_suffix,
         }
         for _, name in ipairs(variants) do
            names[name] = luaver
            table.insert(names, name)
         end
      end

      find_lua_bindir = function(prefix, luaver)
         local names = {}
         if luaver then
            insert_lua_variants(names, luaver)
         else
            for v in util.lua_versions("descending") do
               insert_lua_variants(names, v)
            end
         end
         if luaver == "5.1" or not luaver then
            table.insert(names, "luajit" .. exe_suffix)
         end
         table.insert(names, "lua" .. exe_suffix)

         local bindirs = { prefix .. "/bin", prefix }
         local tried = {}
         for _, d in ipairs(bindirs) do
            for _, name in ipairs(names) do
               local lua_exe = d .. "/" .. name
               local is_wrapper, err = util.lua_is_wrapper(lua_exe)
               if is_wrapper == false then
                  local lv, ljv = util.check_lua_version(lua_exe, luaver)
                  if lv then
                     return name, d, lv, ljv
                  end
               elseif is_wrapper == true or err == nil then
                  table.insert(tried, lua_exe)
               else
                  table.insert(tried, string.format("%-13s (%s)", lua_exe, err))
               end
            end
         end
         local interp = luaver
                        and ("Lua " .. luaver .. " interpreter")
                        or  "Lua interpreter"
         return nil, interp .. " not found at " .. prefix .. "\n" ..
                     "Tried:\t" .. table.concat(tried, "\n\t")
      end
   end

   function util.find_lua(prefix, luaver)
      local lua_interpreter, bindir, luajitver
      lua_interpreter, bindir, luaver, luajitver = find_lua_bindir(prefix, luaver)
      if not lua_interpreter then
         return nil, bindir
      end

      return {
         lua_version = luaver,
         luajit_version = luajitver,
         lua_interpreter = lua_interpreter,
         lua_dir = prefix,
         lua_bindir = bindir,
      }
   end
end

function util.lua_is_wrapper(interp)
   local fd, err = io.open(interp, "r")
   if not fd then
      return nil, err
   end
   local data, err = fd:read(1000)
   fd:close()
   if not data then
      return nil, err
   end
   return not not data:match("LUAROCKS_SYSCONFDIR")
end

function util.opts_table(type_name, valid_opts)
   local opts_mt = {}
   
   opts_mt.__index = opts_mt
   
   function opts_mt.type()
      return type_name
   end

   return function(opts)
      for k, v in pairs(opts) do
         local tv = type(v)
         if not valid_opts[k] then
            error("invalid option: "..k)
         end
         local vo, optional = valid_opts[k]:match("^(.-)(%??)$")
         if not (tv == vo or (optional == "?" and tv == nil)) then
            error("invalid type option: "..k.." - got "..tv..", expected "..vo)
         end
      end
      for k, v in pairs(valid_opts) do
         if (not v:find("?", 1, true)) and opts[k] == nil then
            error("missing option: "..k)
         end
      end
      return setmetatable(opts, opts_mt)
   end
end

return util

