
--- @module luarocks.path_cmd
-- Driver for the `luarocks path` command.
local path_cmd = {}

local util = require("luarocks.util")
local deps = require("luarocks.deps")
local cfg = require("luarocks.cfg")
local path = require("luarocks.path")

--- Driver function for "path" command.
-- @return boolean This function always succeeds.
function path_cmd.run(...)
   local flags = util.parse_flags(...)
   local deps_mode = deps.get_deps_mode(flags)
   
   local lr_path, lr_cpath = cfg.package_paths()
   local bin_dirs = path.map_trees(deps_mode, path.deploy_bin_dir)

   if flags["lr-path"] then
      util.printout(util.remove_path_dupes(lr_path, ';'))
      return true
   elseif flags["lr-cpath"] then
      util.printout(util.remove_path_dupes(lr_cpath, ';'))
      return true
   elseif flags["lr-bin"] then
      local lr_bin = util.remove_path_dupes(table.concat(bin_dirs, cfg.export_path_separator), cfg.export_path_separator)
      util.printout(util.remove_path_dupes(lr_bin, ';'))
      return true
   end
   
   if flags["append"] then
      lr_path = package.path .. ";" .. lr_path
      lr_cpath = package.cpath .. ";" .. lr_cpath
   else
      lr_path =  lr_path.. ";" .. package.path
      lr_cpath = lr_cpath .. ";" .. package.cpath
   end

   util.printout(cfg.export_lua_path:format(util.remove_path_dupes(lr_path, ';')))
   util.printout(cfg.export_lua_cpath:format(util.remove_path_dupes(lr_cpath, ';')))
   if flags["bin"] then
      table.insert(bin_dirs, 1, os.getenv("PATH"))
      local lr_bin = util.remove_path_dupes(table.concat(bin_dirs, cfg.export_path_separator), cfg.export_path_separator)
      util.printout(cfg.export_path:format(lr_bin))
   end
   return true
end

return path_cmd
