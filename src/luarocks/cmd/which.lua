local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type


local which_cmd = {}


local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")

local path = require("luarocks.core.path")
local manif = require("luarocks.core.manif")

















function which_cmd.add_to_parser(parser)
   local cmd = parser:command("which", 'Given a module name like "foo.bar", ' ..
   "output which file would be loaded to resolve that module by " ..
   'luarocks.loader, like "/usr/local/lua/' .. cfg.lua_version .. '/foo/bar.lua".',
   util.see_also()):
   summary("Tell which file corresponds to a given module name.")

   cmd:argument("modname", "Module name.")
end

local function sort_versions(a, b)
   return a.version > b.version
end















local function add_providers(providers, entries, tree, module, filter_name)
   for i, entry in ipairs(entries) do
      local name, version = entry:match("^([^/]*)/(.*)$")

      local file_name = tree.manifest.repository[name][version][1].modules[module]
      if not (type(file_name) == "string") then
         error("Invalid data in manifest file for module " .. tostring(module) .. " (invalid data for " .. tostring(name) .. " " .. tostring(version) .. ")")
      end

      file_name = filter_name(file_name, name, version, tree.tree, i)

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
         add_providers(providers, entries, tree, module, filter_name)
      else
         initmodule = initmodule or module .. ".init"
         entries = tree.manifest.modules[initmodule]
         if entries then
            add_providers(providers, entries, tree, initmodule, filter_name)
         end
      end
   end

   if next(providers) then
      table.sort(providers, sort_versions)
      local first = providers[1]
      return first.name, first.version.string, first.module_name
   end
end













local function which(module, where)
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



function which_cmd.command(args)
   local pathname, rock_name, rock_version, where = which(args.modname, "lp")

   if pathname then
      util.printout(pathname)
      if where == "l" then
         util.printout("(provided by " .. tostring(rock_name) .. " " .. tostring(rock_version) .. ")")
      else
         local key = rock_name
         util.printout("(found directly via package." .. key .. " -- not installed as a rock?)")
      end
      return true
   end

   return nil, "Module '" .. args.modname .. "' not found."
end

return which_cmd
