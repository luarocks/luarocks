
--- @module luarocks.which_cmd
-- Driver for the `luarocks which` command.
local which_cmd = {}

local loader = require("luarocks.loader")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local fs = require("luarocks.fs")

function which_cmd.add_to_parser(parser)
   local cmd = parser:command("which", 'Given a module name like "foo.bar", '..
      "output which file would be loaded to resolve that module by "..
      'luarocks.loader, like "/usr/local/lua/'..cfg.lua_version..'/foo/bar.lua".',
      util.see_also())
      :summary("Tell which file corresponds to a given module name.")

   cmd:argument("modname", "Module name.")
end

--- Driver function for "which" command.
-- @return boolean This function terminates the interpreter.
function which_cmd.command(args)
   local pathname, rock_name, rock_version = loader.which(args.modname)

   if pathname then
      util.printout(pathname)
      util.printout("(provided by " .. tostring(rock_name) .. " " .. tostring(rock_version) .. ")")
      return true
   end

   local modpath = args.modname:gsub("%.", "/")
   for _, v in ipairs({"path", "cpath"}) do
      for p in package[v]:gmatch("([^;]+)") do
         local pathname = p:gsub("%?", modpath)  -- luacheck: ignore 421
         if fs.exists(pathname) then
            util.printout(pathname)
            util.printout("(found directly via package." .. v .. " -- not installed as a rock?)")
            return true
         end
      end
   end

   return nil, "Module '" .. args.modname .. "' not found."
end

return which_cmd

