local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type





local core = require("luarocks.core.util")
local cfg = require("luarocks.core.cfg")




local util = { Fn = {} }




















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







local scheduled_functions = {}








function util.schedule_function(f, x)
   local item = { fn = f, arg = x }
   table.insert(scheduled_functions, item)
   return item
end





function util.remove_scheduled_function(item)
   for k, v in ipairs(scheduled_functions) do
      if v == item then
         table.remove(scheduled_functions, k)
         return
      end
   end
end






function util.run_scheduled_functions()
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











function util.warn_if_not_used(var_defs, needed_set, msg)
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









function util.variable_substitutions(tbl, vars)

   local updated = {}
   for k, v in pairs(tbl) do
      if type(v) == "string" then
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


function util.printout(...)
   io.stdout:write(table.concat({ ... }, "\t"))
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
      local dbg = debug and debug.getinfo(i, "S")
      if not dbg then break end
      last = cur
      cur = dbg.source
      i = i + 1
   end
   local prog = last:sub(1, 1) == "@" and last:sub(2) or last


   local lrdir, binpath = prog:match("^(.*)/lib/luarocks/rocks%-[0-9.]*/[^/]+/[^/]+(/bin/[^/]+)$")
   if lrdir then

      return lrdir .. binpath
   end

   return prog
end

function util.format_rock_name(name, namespace, version)
   return (namespace and namespace .. "/" or "") .. name .. (version and " " .. version or "")
end

function util.deps_mode_option(parser, program)

   parser:option("--deps-mode", "How to handle dependencies. Four modes are supported:\n" ..
   "* all - use all trees from the rocks_trees list for finding dependencies\n" ..
   "* one - use only the current tree (possibly set with --tree)\n" ..
   "* order - use trees based on order (use the current tree and all " ..
   "trees below it on the rocks_trees list)\n" ..
   "* none - ignore dependencies altogether.\n" ..
   "The default mode may be set with the deps_mode entry in the configuration file.\n" ..
   'The current default is "' .. cfg.deps_mode .. '".\n' ..
   "Type '" .. util.this_program(program or "luarocks") .. "' with no " ..
   "arguments to see your list of rocks trees."):
   argname("<mode>"):
   choices({ "all", "one", "order", "none" })
   parser:flag("--nodeps"):hidden(true)
end

function util.see_help(command, program)
   return "See '" .. util.this_program(program or "luarocks") .. ' help' .. (command and " " .. command or "") .. "'."
end

function util.see_also(text)
   local see_also = "See also:\n"
   if text then
      see_also = see_also .. text .. "\n"
   end
   return see_also .. "   '" .. util.this_program("luarocks") .. " help' for general options and configuration."
end

function util.announce_install(rockspec)
   local path = require("luarocks.path")

   local suffix = ""
   if rockspec.description and rockspec.description.license then
      suffix = " (license: " .. rockspec.description.license .. ")"
   end

   util.printout(rockspec.name .. " " .. rockspec.version .. " is now installed in " .. path.root_dir(cfg.root_dir) .. suffix)
   util.printout()
end







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



function util.get_default_rockspec()

   local versions = {}
   local paths = {}
   local unnamed_paths = {}

   collect_rockspecs(versions, paths, unnamed_paths, ".")
   collect_rockspecs(versions, paths, unnamed_paths, "rockspec")
   collect_rockspecs(versions, paths, unnamed_paths, "rockspecs")

   if #unnamed_paths > 0 then


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




function util.LQ(s)
   return ("%q"):format(s)
end




function util.split_namespace(ns_name)
   local p1, p2 = ns_name:match("^([^/]+)/([^/]+)$")
   if p1 then
      return p2, p1
   end
   return ns_name
end


function util.namespaced_name_action(args, target, ns_name)

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

function util.lua_is_wrapper(interp)
   local fd, err = io.open(interp, "r")
   if not fd then
      return nil, err
   end
   local data
   data, err = fd:read(1000)
   fd:close()
   if not data then
      return nil, err
   end
   return not not data:match("LUAROCKS_SYSCONFDIR")
end

do
   local function Q(pathname)
      if pathname:match("^.:") then
         return pathname:sub(1, 2) .. '"' .. pathname:sub(3) .. '"'
      end
      return '"' .. pathname .. '"'
   end

   function util.check_lua_version(lua, luaver)
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

   function util.get_luajit_version()
      if cfg.cache.luajit_version_checked then
         return cfg.cache.luajit_version
      end
      cfg.cache.luajit_version_checked = true

      if not cfg.variables.LUA then
         return nil
      end

      local ljv
      if cfg.lua_version == "5.1" then

         ljv = util.popen_read(Q(cfg.variables.LUA) .. ' -e "io.write(tostring(jit and jit.version:gsub([[^%S+ (%S+).*]], [[%1]])))"')
         if ljv == "nil" then
            ljv = nil
         end
      end
      cfg.cache.luajit_version = ljv
      return ljv
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
            table.insert(names, name)
         end
      end

      find_lua_bindir = function(prefix, luaver, verbose)
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
         local interp = luaver and
         ("Lua " .. luaver .. " interpreter") or
         "Lua interpreter"
         return nil, interp .. " not found at " .. prefix .. "\n" ..
         (verbose and "Tried:\t" .. table.concat(tried, "\n\t") or "")
      end
   end

   function util.find_lua(prefix, luaver, verbose)
      local lua, bindir
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









function util.get_rocks_provided(rockspec)

   if not rockspec and cfg.cache.rocks_provided then
      return cfg.cache.rocks_provided
   end

   local rocks_provided = {}

   local lv = cfg.lua_version

   rocks_provided["lua"] = lv .. "-1"

   if lv == "5.2" then
      rocks_provided["bit32"] = lv .. "-1"
   end

   if lv == "5.3" or lv == "5.4" then
      rocks_provided["utf8"] = lv .. "-1"
   end

   if lv == "5.1" then
      local ljv = util.get_luajit_version()
      if ljv then
         rocks_provided["luabitop"] = ljv .. "-1"
         if (not rockspec) or rockspec:format_is_at_least("3.0") then
            rocks_provided["luajit"] = ljv .. "-1"
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

function util.remove_doc_dir(name, version)
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
