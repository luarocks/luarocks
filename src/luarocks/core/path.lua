local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type
local path = {}


local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.core.dir")



local dir_sep = package.config:sub(1, 1)


function path.rocks_dir(tree)
   if tree == nil then
      tree = cfg.root_dir
      if tree == nil then
         error("root_dir could not be determined in configuration")
      end
   end
   if type(tree) == "string" then
      return dir.path(tree, cfg.rocks_subdir)
   end
   if tree.rocks_dir then
      return tree.rocks_dir
   end
   if tree.root and cfg.rocks_subdir then
      return dir.path(tree.root, cfg.rocks_subdir)
   end
   error("invalid configuration for local repository")
end







function path.versioned_name(file, prefix, name, version)
   assert(not name:match(dir_sep))

   local rest = file:sub(#prefix + 1):gsub("^" .. dir_sep .. "*", "")
   local name_version = (name .. "_" .. version):gsub("%-", "_"):gsub("%.", "_")
   return dir.path(prefix, name_version .. "-" .. rest)
end








function path.path_to_module(file)

   local exts = {}
   local paths = package.path .. ";" .. package.cpath
   for entry in paths:gmatch("[^;]+") do
      local ext = entry:match("%.([a-z]+)$")
      if ext then
         exts[ext] = true
      end
   end

   local name
   for ext, _ in pairs(exts) do
      name = file:match("(.*)%." .. ext .. "$")
      if name then
         name = name:gsub("[\\/]", ".")
         break
      end
   end

   if not name then name = file end


   name = name:gsub("^%.+", ""):gsub("%.+$", "")

   return name
end

function path.deploy_lua_dir(tree)
   if type(tree) == "string" then
      return dir.path(tree, cfg.lua_modules_path)
   else
      return tree.lua_dir or dir.path(tree.root, cfg.lua_modules_path)
   end
end

function path.deploy_lib_dir(tree)
   if type(tree) == "string" then
      return dir.path(tree, cfg.lib_modules_path)
   else
      return tree.lib_dir or dir.path(tree.root, cfg.lib_modules_path)
   end
end

local is_src_extension = { [".lua"] = true, [".tl"] = true, [".tld"] = true, [".moon"] = true }









function path.which_i(file_name, name, version, tree, i)
   local deploy_dir
   local extension = file_name:match("%.[a-z]+$")
   if is_src_extension[extension] then
      deploy_dir = path.deploy_lua_dir(tree)
      file_name = dir.path(deploy_dir, file_name)
   else
      deploy_dir = path.deploy_lib_dir(tree)
      file_name = dir.path(deploy_dir, file_name)
   end
   if i > 1 then
      file_name = path.versioned_name(file_name, deploy_dir, name, version)
   end
   return file_name
end

function path.rocks_tree_to_string(tree)
   if type(tree) == "string" then
      return tree
   else
      return tree.root
   end
end








function path.map_trees(deps_mode, fn, ...)
   local result = {}
   local current = cfg.root_dir or cfg.rocks_trees[1]
   if deps_mode == "one" then
      table.insert(result, (fn(current, ...)) or 0)
   else
      local use = false
      if deps_mode == "all" then
         use = true
      end
      for _, tree in ipairs(cfg.rocks_trees or {}) do
         if dir.normalize(path.rocks_tree_to_string(tree)) == dir.normalize(path.rocks_tree_to_string(current)) then
            use = true
         end
         if use then
            table.insert(result, (fn(tree, ...)) or 0)
         end
      end
   end
   return result
end

return path
