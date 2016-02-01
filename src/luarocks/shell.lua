
--- @module luarocks.shell
-- Driver for the `luarocks shell` command.
local shell_cmd = {}

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local fs = require("luarocks.fs")

shell_cmd.help_summary = "Starts a new shell with the variables from `luarocks path` correctly set."
shell_cmd.help_arguments = ""
shell_cmd.help = [[
Starts a new shell with the variables LUA_PATH and LUA_CPATH set as 
configured by the LuaRocks installation.
]]

--- Driver function for "shell" command.
-- @return boolean This function always succeeds.
function shell_cmd.run(...)
   local lr_path, lr_cpath = cfg.package_paths()
   local path_sep = cfg.export_path_separator
   
   lr_path =  lr_path.. ";" .. package.path
   lr_cpath = lr_cpath .. ";" .. package.cpath

   lr_path = cfg.export_lua_path:format(util.remove_path_dupes(lr_path, ';'))
   lr_cpath = cfg.export_lua_cpath:format(util.remove_path_dupes(lr_cpath, ';'))

   local shell, cmd = os.getenv("SHELL")
   if shell then
      cmd = ([[LUA_PATH="%s" LUA_CPATH="%s" "%s"]]):format(lr_path, lr_cpath, shell)
   else
      cmd = ([[cmd /k "%s && %s"]]):format(lr_path, lr_cpath)
   end
   return fs.execute(cmd)
end

return shell_cmd
