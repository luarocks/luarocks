
--- Module implementing the LuaRocks "help" command.
-- This is a generic help display module, which
-- uses a global table called "commands" to find commands
-- to show help for; each command should be represented by a
-- table containing "help" and "help_summary" fields.
module("luarocks.help", package.seeall)

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")

help_summary = "Help on commands."

help_arguments = "[<command>]"
help = [[
<command> is the command to show help for.
]]

--- Driver function for the "help" command.
-- @param command string or nil: command to show help for; if not
-- given, help summaries for all commands are shown.
-- @return boolean or (nil, string): true if there were no errors
-- or nil and an error message if an invalid command was requested.
function run(...)
   local flags, command = util.parse_flags(...)

   if not command then
      print([[
LuaRocks ]]..cfg.program_version..[[, a module deployment system for Lua

]]..program_name..[[ - ]]..program_description..[[

usage: ]]..program_name..[[ [--from=<server> | --only-from=<server>] [--to=<tree>] [VAR=VALUE]... <command> [<argument>]

Variables from the "variables" table of the configuration file
can be overriden with VAR=VALUE assignments.

--from=<server>       Fetch rocks/rockspecs from this server
                      (takes priority over config file)
--only-from=<server>  Fetch rocks/rockspecs from this server only
                      (overrides any entries in the config file)
--to=<tree>           Which tree to operate on.

Supported commands:
]])
      local names = {}
      for name, command in pairs(commands) do
         table.insert(names, name)
      end
      table.sort(names)
      for _, name in ipairs(names) do
         local command = commands[name]
         print(name, command.help_summary)
      end
   else
      command = command:gsub("-", "_")
      if commands[command] then
         local arguments = commands[command].help_arguments or "<argument>"
         print()
         print(program_name.." "..command.." "..arguments)
         print()
         print(command.." - "..commands[command].help_summary)
         print()
         print(commands[command].help)
      else
         return nil, "Unknown command '"..command.."'"
      end
   end
   return true
end
