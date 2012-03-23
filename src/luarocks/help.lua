
--- Module implementing the LuaRocks "help" command.
-- This is a generic help display module, which
-- uses a global table called "commands" to find commands
-- to show help for; each command should be represented by a
-- table containing "help" and "help_summary" fields.
module("luarocks.help", package.seeall)

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")

help_summary = "Help on commands. Type '"..program_name.." help <command>' for more."

help_arguments = "[<command>]"
help = [[
<command> is the command to show help for.
]]

local function print_banner()
   util.printout("\nLuaRocks "..cfg.program_version..", a module deployment system for Lua")
end

local function print_section(section)
   util.printout("\n"..section)
end

local function get_status(status)
   if status then
      return "ok"
   elseif status == false then
      return "not found"
   else
      return "failed"
   end
end

--- Driver function for the "help" command.
-- @param command string or nil: command to show help for; if not
-- given, help summaries for all commands are shown.
-- @return boolean or (nil, string): true if there were no errors
-- or nil and an error message if an invalid command was requested.
function run(...)
   local flags, command = util.parse_flags(...)

   if not command then
      local sys_file, sys_ok, home_file, home_ok = cfg.which_config()
      print_banner()
      print_section("NAME")
      util.printout("\t"..program_name..[[ - ]]..program_description)
      print_section("SYNOPSIS")
      util.printout("\t"..program_name..[[ [--from=<server> | --only-from=<server>] [--to=<tree>] [VAR=VALUE]... <command> [<argument>] ]])
      print_section("GENERAL OPTIONS")
      util.printout([[
	These apply to all commands, as appropriate:

	--server=<server>      Fetch rocks/rockspecs from this server
	                       (takes priority over config file)
	--only-server=<server> Fetch rocks/rockspecs from this server only
	                       (overrides any entries in the config file)
	--only-sources=<url>   Restrict downloads to paths matching the
	                       given URL.
	--tree=<tree>          Which tree to operate on.
	--local                Use the tree in the user's home directory.]])
      print_section("VARIABLES")
      util.printout([[
	Variables from the "variables" table of the configuration file
	can be overriden with VAR=VALUE assignments.]])
      print_section("COMMANDS")
      local names = {}
      for name, command in pairs(commands) do
         table.insert(names, name)
      end
      table.sort(names)
      for _, name in ipairs(names) do
         local command = commands[name]
         util.printout("", name)
         util.printout("\t", command.help_summary)
      end
      print_section("CONFIGURATION")
      util.printout([[
	System configuration file: ]]..sys_file .. " (" .. get_status(sys_ok) ..[[)
	User configuration file: ]]..home_file .. " (" .. get_status(home_ok) ..")\n")
   else
      command = command:gsub("-", "_")
      if commands[command] then
         local arguments = commands[command].help_arguments or "<argument>"
         print_banner()
         print_section("NAME")
         util.printout("\t"..program_name.." "..command.." - "..commands[command].help_summary)
         print_section("SYNOPSIS")
         util.printout("\t"..program_name.." "..command.." "..arguments)
         print_section("DESCRIPTION")
         util.printout("",(commands[command].help:gsub("\n","\n\t"):gsub("\n\t$","")))
         print_section("SEE ALSO")
         util.printout("","'luarocks help' for general options and configuration.\n")
      else
         return nil, "Unknown command '"..command.."'"
      end
   end
   return true
end
