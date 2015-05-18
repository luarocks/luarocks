--- Module implementing the LuaRocks "config" command.
-- Queries information about the LuaRocks configuration.
local config_cmd = {}

local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local dir = require("luarocks.dir")

local function config_file(conf)
   print(dir.normalize(conf.file))
   if conf.ok then
      return true
   else
      return nil, "file not found"
   end
end

--- Driver function for "config" command.
-- @return boolean: True if succeeded, nil on errors.
function config_cmd.run(...)
   local flags = util.parse_flags(...)
   
   if flags["lua-incdir"] then
      print(cfg.variables.LUA_INCDIR)
      return true
   end
   if flags["lua-libdir"] then
      print(cfg.variables.LUA_LIBDIR)
      return true
   end
   if flags["lua-ver"] then
      print(cfg.lua_version)
      return true
   end
   local conf = cfg.which_config()
   if flags["system-config"] then
      return config_file(conf.system)
   end
   if flags["user-config"] then
      return config_file(conf.user)
   end

   if flags["rock-trees"] then
      for _, tree in ipairs(cfg.rocks_trees) do
      	if type(tree) == "string" then
      	   util.printout(dir.normalize(tree))
      	else
      	   local name = tree.name and "\t"..tree.name or ""
      	   util.printout(dir.normalize(tree.root)..name)
      	end
      end
      return true
   end
   
   return nil, "Please provide a flag for querying configuration values. "..util.see_help("config")
end

return config_cmd
