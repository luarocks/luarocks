local config = {}

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local fs = require("luarocks.fs")
local util = require("luarocks.util")

local function replace_tree(tree)
   tree = dir.normalize(tree)
   path.use_tree(tree)
end

function config.set_rock_tree(tree_arg)
   if tree_arg then
      local named = false
      for _, tree in ipairs(cfg.rocks_trees) do
         if type(tree) == "table" and tree_arg == tree.name then
            if not tree.root then
               die("Configuration error: tree '"..tree.name.."' has no 'root' field.")
            end
            replace_tree(tree.root)
            named = true
            break
         end
      end
      if not named then
         fs.init()
         local root_dir = fs.absolute_name(tree_arg)
         replace_tree(root_dir)
      end
   else
      local trees = cfg.rocks_trees
      path.use_tree(trees[#trees])
   end
   
   if type(cfg.root_dir) == "string" then
      cfg.root_dir = cfg.root_dir:gsub("/+$", "")
   else
      cfg.root_dir.root = cfg.root_dir.root:gsub("/+$", "")
   end
end

function config.list_rock_trees()
	return util.deep_copy(cfg.rocks_trees)
end

function config.set_rocks_servers(server, mode)
   if not mode then
      local protocol, pathname = dir.split_url(server)
      table.insert(cfg.rocks_servers, 1, protocol .. "://" .. pathname)
   elseif mode == "dev" then
      local append_dev = function(s) return dir.path(s, "dev") end
      local dev_servers = fun.traverse(cfg.rocks_servers, append_dev)
      cfg.rocks_servers = fun.concat(dev_servers, cfg.rocks_servers)
   elseif mode == "only" then
      cfg.rocks_servers = { server }
   end
end

function config.list_rocks_servers()
   return util.deep_copy(cfg.rocks_servers)
end

return config
