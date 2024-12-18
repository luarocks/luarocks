local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type




local cfg = require("luarocks.core.cfg")
local core = require("luarocks.core.path")
local dir = require("luarocks.dir")
local util = require("luarocks.core.util")



local path = {}









path.rocks_dir = core.rocks_dir
path.versioned_name = core.versioned_name
path.path_to_module = core.path_to_module
path.deploy_lua_dir = core.deploy_lua_dir
path.deploy_lib_dir = core.deploy_lib_dir
path.map_trees = core.map_trees
path.rocks_tree_to_string = core.rocks_tree_to_string

function path.root_dir(tree)
   if type(tree) == "string" then
      return tree
   else
      return tree.root
   end
end




function path.rockspec_name_from_rock(rock_name)
   local base_name = dir.base_name(rock_name)
   return base_name:match("(.*)%.[^.]*.rock") .. ".rockspec"
end

function path.root_from_rocks_dir(rocks_dir)
   return rocks_dir:match("(.*)" .. util.matchquote(cfg.rocks_subdir) .. ".*$")
end

function path.deploy_bin_dir(tree)
   return dir.path(path.root_dir(tree), "bin")
end

function path.manifest_file(tree)
   return dir.path(path.rocks_dir(tree), "manifest")
end






function path.versions_dir(name, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name)
end







function path.install_dir(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version)
end







function path.rockspec_file(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, name .. "-" .. version .. ".rockspec")
end







function path.rock_manifest_file(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, "rock_manifest")
end







function path.rock_namespace_file(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, "rock_namespace")
end







function path.lib_dir(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, "lib")
end







function path.lua_dir(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, "lua")
end







function path.doc_dir(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, "doc")
end







function path.conf_dir(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, "conf")
end








function path.bin_dir(name, version, tree)
   assert(not name:match("/"))
   return dir.path(path.rocks_dir(tree), name, version, "bin")
end






function path.parse_name(file_name)
   if file_name:match("%.rock$") then
      return dir.base_name(file_name):match("(.*)-([^-]+-%d+)%.([^.]+)%.rock$")
   else
      return dir.base_name(file_name):match("(.*)-([^-]+-%d+)%.(rockspec)")
   end
end







function path.make_url(pathname, name, version, arch)
   assert(not name:match("/"))
   local filename = name .. "-" .. version
   if arch == "installed" then
      filename = dir.path(name, version, filename .. ".rockspec")
   elseif arch == "rockspec" then
      filename = filename .. ".rockspec"
   else
      filename = filename .. "." .. arch .. ".rock"
   end
   return dir.path(pathname, filename)
end





function path.module_to_path(mod)
   return (mod:gsub("[^.]*$", ""):gsub("%.", "/"))
end

function path.use_tree(tree)
   cfg.root_dir = tree
   cfg.rocks_dir = path.rocks_dir(tree)
   cfg.deploy_bin_dir = path.deploy_bin_dir(tree)
   cfg.deploy_lua_dir = path.deploy_lua_dir(tree)
   cfg.deploy_lib_dir = path.deploy_lib_dir(tree)
end

function path.add_to_package_paths(tree)
   package.path = dir.path(path.deploy_lua_dir(tree), "?.lua") .. ";" ..
   dir.path(path.deploy_lua_dir(tree), "?/init.lua") .. ";" ..
   package.path
   package.cpath = dir.path(path.deploy_lib_dir(tree), "?." .. cfg.lib_extension) .. ";" ..
   package.cpath
end






function path.read_namespace(name, version, tree)
   assert(not name:match("/"))

   local namespace
   local fd = io.open(path.rock_namespace_file(name, version, tree), "r")
   if fd then
      namespace = fd:read("*a")
      fd:close()
   end
   return namespace
end

function path.package_paths(deps_mode)
   local lpaths = {}
   local lcpaths = {}
   path.map_trees(deps_mode, function(tree)
      local root = path.root_dir(tree)
      table.insert(lpaths, dir.path(root, cfg.lua_modules_path, "?.lua"))
      table.insert(lpaths, dir.path(root, cfg.lua_modules_path, "?/init.lua"))
      table.insert(lcpaths, dir.path(root, cfg.lib_modules_path, "?." .. cfg.lib_extension))
   end)
   return table.concat(lpaths, ";"), table.concat(lcpaths, ";")
end

return path
