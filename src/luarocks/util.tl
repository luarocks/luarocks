
--- Assorted utilities for managing tables, plus a scheduler for rollback functions.
-- Does not requires modules directly (only as locals
-- inside specific functions) to avoid interdependencies,
-- as this is used in the bootstrapping stage of luarocks.core.cfg.

local core = require("luarocks.core.util")
local cfg = require("luarocks.core.cfg")

local type Ordering= require("luarocks.core.types.ordering").Ordering
local type SortBy = require("luarocks.core.types.ordering").SortBy

local record util
   cleanup_path: function(string, string, string, boolean): string
   split_string: function(string, string, ?number): {string}
   sortedpairs: function<K, V>(tbl: {K: V}, sort_by?: SortBy<K>): function(): K, V, Ordering<K>
   deep_merge: function({any : any}, {any : any})
   deep_merge_under: function({any : any}, {any : any})
   popen_read: function(string, ?string): string
   show_table: function({any : any}, string, string): string
   printerr: function(...: string | number)
   warning: function(string)
   keys: function<K, V>({K : V}): {K}
   matchquote: function(string): string
   exists: function(string): boolean
   starts_with: function(s: string, prefix: string): boolean

   record Fn
      fn: function(any)
      arg: any
   end
end

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
util.matchquote = core.matchquote
util.exists = core.exists
util.starts_with = core.starts_with

local type Fn = util.Fn
local type Rockspec = require("luarocks.core.types.rockspec").Rockspec

local type Parser = require("luarocks.vendor.argparse").Parser


local scheduled_functions: {Fn} = {}

--- Schedule a function to be executed upon program termination.
-- This is useful for actions such as deleting temporary directories
-- or failure rollbacks.
-- @param f function: Function to be executed.
-- @param ... arguments to be passed to function.
-- @return table: A token representing the scheduled execution,
-- which can be used to remove the item later from the list.
function util.schedule_function<X>(f: function(X...), x?: X): Fn
   local item: Fn = { fn = f, arg = x }
   table.insert(scheduled_functions, item)
   return item
end

--- Unschedule a function.
-- This is useful for cancelling a rollback of a completed operation.
-- @param item table: The token representing the scheduled function that was
-- returned from the schedule_function call.
function util.remove_scheduled_function(item: Fn)
   for k, v in ipairs(scheduled_functions) do
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
function util.run_scheduled_functions(): string --! a hack for xpcall
   local fs = require("luarocks.fs")
   if fs.change_dir_to_root then
      fs.change_dir_to_root()
   end
   for i = #scheduled_functions, 1, -1 do
      local item = scheduled_functions[i]
      item.fn(item.arg)
   end
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
function util.warn_if_not_used(var_defs: {string: string}, needed_set: {string: boolean}, msg: string)
   local seen = {}
   for _, val in pairs(var_defs) do
      for used in val:gmatch(var_format_pattern) do
         seen[used] = true
      end
   end
   for var, _ in pairs(needed_set) do
      if not seen[var] then
         util.warning(msg:format(var))
      end
   end
end

-- Output any entries that might remain in $(XYZ) format,
-- warning the user that substitutions have failed.
-- @param line string: the input string
local function warn_failed_matches(line: string): boolean
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
function util.variable_substitutions<K>(tbl: {K: string}, vars: {string: string})

   local updated: {K: string} = {}
   for k, v in pairs(tbl) do
      if v is string then
         updated[k] = string.gsub(v, var_format_pattern, vars)
         if warn_failed_matches(updated[k]) then
            updated[k] = updated[k]:gsub(var_format_pattern, "")
         end
      end
   end
   for k, v in pairs(updated) do
      tbl[k] = v
   end
end

function util.lua_versions(sort?: string): function(): string
   local versions = { "5.1", "5.2", "5.3", "5.4" }
   local i = 0
   if sort == "descending" then
      i = #versions + 1
      return function(): string
         i = i - 1
         return versions[i]
      end
   else
      return function(): string
         i = i + 1
         return versions[i]
      end
   end
end

function util.lua_path_variables(): string, string
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

--- Print a line to standard output
function util.printout(...: string)
   io.stdout:write(table.concat({...},"\t"))
   io.stdout:write("\n")
end

function util.title(msg: string, porcelain?: boolean, underline?: string)
   if porcelain then return end
   util.printout()
   util.printout(msg)
   util.printout((underline or "-"):rep(#msg))
   util.printout()
end

function util.this_program(default: string): string
   local i = 1
   local last, cur = default, default
   while i do
      local dbg = debug and debug.getinfo(i,"S")
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

function util.format_rock_name(name: string, namespace: string, version: string): string
   return (namespace and namespace.."/" or "")..name..(version and " "..version or "")
end

function util.deps_mode_option(parser: Parser, program?: string)

   parser:option("--deps-mode", "How to handle dependencies. Four modes are supported:\n"..
      "* all - use all trees from the rocks_trees list for finding dependencies\n"..
      "* one - use only the current tree (possibly set with --tree)\n"..
      "* order - use trees based on order (use the current tree and all "..
      "trees below it on the rocks_trees list)\n"..
      "* none - ignore dependencies altogether.\n"..
      "The default mode may be set with the deps_mode entry in the configuration file.\n"..
      'The current default is "'..cfg.deps_mode..'".\n'..
      "Type '"..util.this_program(program or "luarocks").."' with no "..
      "arguments to see your list of rocks trees.")
      :argname("<mode>")
      :choices({"all", "one", "order", "none"})
   parser:flag("--nodeps"):hidden(true)
end

function util.see_help(command: string, program?: string): string
   return "See '"..util.this_program(program or "luarocks")..' help'..(command and " "..command or "").."'."
end

function util.see_also(text?: string): string
   local see_also = "See also:\n"
   if text then
      see_also = see_also..text.."\n"
   end
   return see_also.."   '"..util.this_program("luarocks").." help' for general options and configuration."
end

function util.announce_install(rockspec: Rockspec)
   local path = require("luarocks.path") --TEAL BUG?

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
local function collect_rockspecs(versions: {string: string}, paths: {string: string}, unnamed_paths: {string}, subdir: string)
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
function util.get_default_rockspec(): string, string

   local versions: {string: string} = {}
   local paths: {string: string} = {}
   local unnamed_paths: {string} = {}
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
function util.LQ(s: string): string
   return ("%q"):format(s)
end

-- Split name and namespace of a package name.
-- @param ns_name a name that may be in "namespace/name" format
-- @return string, string? - name and optionally a namespace
function util.split_namespace(ns_name: string): string, string
   local p1, p2 = ns_name:match("^([^/]+)/([^/]+)$")
   if p1 then
      return p2, p1
   end
   return ns_name
end

--- Argparse action callback for namespaced rock arguments.
function util.namespaced_name_action(args: {any: any}, target: string, ns_name: string)

   if not ns_name then
      return
   end

   if ns_name:match("%.rockspec$") or ns_name:match("%.rock$") then
      args[target] = ns_name
   else
      local name, namespace = util.split_namespace(ns_name)
      args[target] = name:lower()
      if namespace then
         args.namespace = namespace:lower()
      end
   end
end

function util.deep_copy(tbl: {any: any}): {any: any}
   local copy: {any: any} = {}
   for k, v in pairs(tbl) do
      if v is {any: any} then
         copy[k] = util.deep_copy(v)
      else
         copy[k] = v
      end
   end
   return copy
end

function util.lua_is_wrapper(interp: string): boolean, string
   local fd, err = io.open(interp, "r")
   if not fd then
      return nil, err
   end
   local data: string
   data, err = fd:read(1000)
   fd:close()
   if not data then
      return nil, err
   end
   return not not data:match("LUAROCKS_SYSCONFDIR")
end

do
   local function Q(pathname: string): string
      if pathname:match("^.:") then
         return pathname:sub(1, 2) .. '"' .. pathname:sub(3) .. '"'
      end
      return '"' .. pathname .. '"'
   end

   function util.check_lua_version(lua:string, luaver: string): string
      if not util.exists(lua) then
         return nil
      end
      local lv = util.popen_read(Q(lua) .. ' -e "io.write(_VERSION:sub(5))"')
      if lv == "" then
         return nil
      end
      if luaver and luaver ~= lv then
         return nil
      end
      return lv
   end

   function util.get_luajit_version(): string
         if cfg.cache.luajit_version_checked then
         return cfg.cache.luajit_version
      end
      cfg.cache.luajit_version_checked = true

      if not cfg.variables.LUA then
         return nil
      end

      local ljv: string
      if cfg.lua_version == "5.1" then
         -- Ignores extra version info for custom builds, e.g. "LuaJIT 2.1.0-beta3 some-other-version-info"
         ljv = util.popen_read(Q(cfg.variables.LUA) .. ' -e "io.write(tostring(jit and jit.version:gsub([[^%S+ (%S+).*]], [[%1]])))"')
         if ljv == "nil" then
            ljv = nil
         end
      end
      cfg.cache.luajit_version = ljv
      return ljv
   end

   local find_lua_bindir: function(prefix: string, luaver: string, verbose: string): string, string, string
   do
      local exe_suffix = (package.config:sub(1, 1) == "\\" and ".exe" or "")

      local function insert_lua_variants(names: {string}, luaver: string)
         local variants = {
            "lua" .. luaver .. exe_suffix,
            "lua" .. luaver:gsub("%.", "") .. exe_suffix,
            "lua-" .. luaver .. exe_suffix,
            "lua-" .. luaver:gsub("%.", "") .. exe_suffix,
         }
         for _, name in ipairs(variants) do
            table.insert(names, name)
         end
      end

      find_lua_bindir = function(prefix: string, luaver: string, verbose: string): string, string, string
         local names: {string} = {}
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

         local tried = {}
         local dir_sep = package.config:sub(1, 1)
         for _, d in ipairs({ prefix .. dir_sep .. "bin", prefix }) do
            for _, name in ipairs(names) do
               local lua = d .. dir_sep .. name
               local is_wrapper, err = util.lua_is_wrapper(lua)
               if is_wrapper == false then
                  local lv = util.check_lua_version(lua, luaver)
                  if lv then
                     return lua, d, lv
                  end
               elseif is_wrapper == true or err == nil then
                  table.insert(tried, lua)
               else
                  table.insert(tried, string.format("%-13s (%s)", lua, err))
               end
            end
         end
         local interp = luaver
                        and ("Lua " .. luaver .. " interpreter")
                        or  "Lua interpreter"
         return nil, interp .. " not found at " .. prefix .. "\n" ..
                     (verbose and "Tried:\t" .. table.concat(tried, "\n\t") or "")
      end
   end

   function util.find_lua(prefix: string, luaver: string, verbose?: string): {string: string}, string
      local lua, bindir: string, string
      lua, bindir, luaver = find_lua_bindir(prefix, luaver, verbose)
      if not lua then
         return nil, bindir
      end

      return {
         lua_version = luaver,
         lua = lua,
         lua_dir = prefix,
         lua_bindir = bindir,
      }
   end
end

--- Return a table of modules that are already provided by the VM, which
-- can be specified as dependencies without having to install an actual rock.
-- @param rockspec (optional) a rockspec table, so that rockspec format
-- version compatibility can be checked. If not given, maximum compatibility
-- is assumed.
-- @return a table with rock names as keys and versions and values,
-- specifying modules that are already provided by the VM (including
-- "lua" for the Lua version and, for format 3.0+, "luajit" if detected).
function util.get_rocks_provided(rockspec?: Rockspec): {string: string}

   if not rockspec and cfg.cache.rocks_provided then
      return cfg.cache.rocks_provided
   end

   local rocks_provided = {}

   local lv = cfg.lua_version

   rocks_provided["lua"] = lv.."-1"

   if lv == "5.2" then
      rocks_provided["bit32"] = lv.."-1"
   end

   if lv == "5.3" or lv == "5.4" then
      rocks_provided["utf8"] = lv.."-1"
   end

   if lv == "5.1" then
      local ljv = util.get_luajit_version()
      if ljv then
         rocks_provided["luabitop"] = ljv.."-1"
         if (not rockspec) or rockspec:format_is_at_least("3.0") then
            rocks_provided["luajit"] = ljv.."-1"
         end
      end
   end

   if cfg.rocks_provided then
      util.deep_merge_under(rocks_provided, cfg.rocks_provided)
   end

   if not rockspec then
      cfg.cache.rocks_provided = rocks_provided
   end

   return rocks_provided
end

function util.remove_doc_dir(name: string, version: string)
   local path = require("luarocks.path")
   local fs = require("luarocks.fs")
   local dir = require("luarocks.dir")

   local install_dir = path.install_dir(name, version)
   for _, f in ipairs(fs.list_dir(install_dir)) do
      local doc_dirs = { "doc", "docs" }
      for _, d in ipairs(doc_dirs) do
         if f == d then
            fs.delete(dir.path(install_dir, f))
         end
      end
   end
end

return util
