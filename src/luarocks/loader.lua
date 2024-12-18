local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type






local loaders = package.loaders or package.searchers
local require, ipairs, table, type, next, tostring, error =
require, ipairs, table, type, next, tostring, error

local loader = {}




local is_clean = not package.loaded["luarocks.core.cfg"]


local cfg = require("luarocks.core.cfg")
local cfg_ok, _err = cfg.init()
if cfg_ok then
   cfg.init_package_paths()
end

local path = require("luarocks.core.path")
local manif = require("luarocks.core.manif")
local vers = require("luarocks.core.vers")

























local temporary_global = false
local status, luarocks_value = pcall(function()
   return luarocks
end)
if status and luarocks_value then



   luarocks.loader = loader
else





   local info = debug and debug.getinfo(2, "nS")
   if info and info.what == "C" and not info.name then
      luarocks = { loader = loader }
      temporary_global = true


   end
end





loader.context = {}






function loader.add_context(name, version)
   if temporary_global then


      luarocks = nil
      temporary_global = false
   end

   local tree_manifests = manif.load_rocks_tree_manifests()
   if not tree_manifests then
      return
   end

   manif.scan_dependencies(name, version, tree_manifests, loader.context)
end







local function sort_versions(a, b)
   return a.version > b.version
end
















local function call_other_loaders(module, name, version, module_name)
   for _, a_loader in ipairs(loaders) do
      if a_loader ~= loader.luarocks_loader then
         local results = { a_loader(module_name) }
         local f = results[1]
         if type(f) == "function" then
            if #results == 2 then
               return f, results[2]
            else
               return f
            end
         end
      end
   end
   return "Failed loading module " .. module .. " in LuaRocks rock " .. name .. " " .. version
end















local function add_providers(providers, entries, tree, module, filter_name)
   for i, entry in ipairs(entries) do
      local name, version = entry:match("^([^/]*)/(.*)$")

      local file_name = tree.manifest.repository[name][version][1].modules[module]
      if type(file_name) ~= "string" then
         error("Invalid data in manifest file for module " .. tostring(module) .. " (invalid data for " .. tostring(name) .. " " .. tostring(version) .. ")")
      end

      file_name = filter_name(file_name, name, version, tree.tree, i)

      if loader.context[name] == version then
         return name, version, file_name
      end

      table.insert(providers, {
         name = name,
         version = vers.parse_version(version),
         module_name = file_name,
         tree = tree,
      })
   end
end













local function select_module(module, filter_name)

   local tree_manifests = manif.load_rocks_tree_manifests()
   if not tree_manifests then
      return nil
   end

   local providers = {}
   local initmodule
   for _, tree in ipairs(tree_manifests) do
      local entries = tree.manifest.modules[module]
      if entries then
         local n, v, f = add_providers(providers, entries, tree, module, filter_name)
         if n then
            return n, v, f
         end
      else
         initmodule = initmodule or module .. ".init"
         entries = tree.manifest.modules[initmodule]
         if entries then
            local n, v, f = add_providers(providers, entries, tree, initmodule, filter_name)
            if n then
               return n, v, f
            end
         end
      end
   end

   if next(providers) then
      table.sort(providers, sort_versions)
      local first = providers[1]
      return first.name, first.version.string, first.module_name
   end
end












local function filter_module_name(file_name, name, version, _tree, i)
   if i > 1 then
      file_name = path.versioned_name(file_name, "", name, version)
   end
   return path.path_to_module(file_name)
end









local function pick_module(module)
   return select_module(module, filter_module_name)
end













function loader.which(module, where)
   where = where or "l"
   if where:match("l") then
      local rock_name, rock_version, file_name = select_module(module, path.which_i)
      if rock_name then
         local fd = io.open(file_name)
         if fd then
            fd:close()
            return file_name, rock_name, rock_version, "l"
         end
      end
   end
   if where:match("p") then
      local modpath = module:gsub("%.", "/")
      for _, v in ipairs({ package.path, package.cpath }) do
         for p in v:gmatch("([^;]+)") do
            local file_name = p:gsub("%?", modpath)
            local fd = io.open(file_name)
            if fd then
               fd:close()
               return file_name, v, nil, "p"
            end
         end
      end
   end
end













function loader.luarocks_loader(module)
   local name, version, module_name = pick_module(module)
   if not name then
      return "No LuaRocks module found for " .. module
   else
      loader.add_context(name, version)
      return call_other_loaders(module, name, version, module_name)
   end
end

table.insert(loaders, 1, loader.luarocks_loader)

if is_clean then
   for modname, _ in pairs(package.loaded) do
      if modname:match("^luarocks%.") then
         package.loaded[modname] = nil
      end
   end
end

return loader
