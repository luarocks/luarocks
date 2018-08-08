local config = {}

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local fs = require("luarocks.fs")

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

return config
