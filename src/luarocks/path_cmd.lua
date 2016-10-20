
--- @module luarocks.path_cmd
-- Driver for the `luarocks path` command.
local path_cmd = {}

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")

util.add_run_function(path_cmd)
path_cmd.help_summary = "Return the currently configured package path."
path_cmd.help_arguments = ""
path_cmd.help = [[
Returns the package path currently configured for this installation
of LuaRocks, formatted as shell commands to update LUA_PATH and LUA_CPATH. 

--bin          Adds the system path to the output

--append       Appends the paths to the existing paths. Default is to prefix
               the LR paths to the existing paths.

--lr-path      Exports the Lua path (not formatted as shell command)

--lr-cpath     Exports the Lua cpath (not formatted as shell command)

--lr-bin       Exports the system path (not formatted as shell command)


On Unix systems, you may run: 
  eval `luarocks path`
And on Windows: 
  luarocks path > "%temp%\_lrp.bat" && call "%temp%\_lrp.bat" && del "%temp%\_lrp.bat"
]]

--- Driver function for "path" command.
-- @return boolean This function always succeeds.
function path_cmd.command(flags)
   local lr_path, lr_cpath, lr_bin = cfg.package_paths(flags["tree"])
   local path_sep = cfg.export_path_separator

   if flags["lr-path"] then
      util.printout(util.remove_path_dupes(lr_path, ';'))
      return true
   elseif flags["lr-cpath"] then
      util.printout(util.remove_path_dupes(lr_cpath, ';'))
      return true
   elseif flags["lr-bin"] then
      util.printout(util.remove_path_dupes(lr_bin, path_sep))
      return true
   end
   
   if flags["append"] then
      lr_path = package.path .. ";" .. lr_path
      lr_cpath = package.cpath .. ";" .. lr_cpath
      lr_bin = os.getenv("PATH") .. path_sep .. lr_bin
   else
      lr_path =  lr_path.. ";" .. package.path
      lr_cpath = lr_cpath .. ";" .. package.cpath
      lr_bin = lr_bin .. path_sep .. os.getenv("PATH")
   end

   util.printout(cfg.export_lua_path:format(util.remove_path_dupes(lr_path, ';')))
   util.printout(cfg.export_lua_cpath:format(util.remove_path_dupes(lr_cpath, ';')))
   if flags["bin"] then
      util.printout(cfg.export_path:format(util.remove_path_dupes(lr_bin, path_sep)))
   end
   return true
end

return path_cmd
