
--- Module implementing the LuaRocks "help" command.
-- This is a generic help display module, which
-- uses a global table called "commands" to find commands
-- to show help for; each command should be represented by a
-- table containing "help" and "help_summary" fields.
local help = {}

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

local program = util.this_program("luarocks")

util.add_run_function(help)
help.help_summary = "Help on commands. Type '"..program.." help <command>' for more."

help.help_arguments = "[<command>]"
help.help = [[
<command> is the command to show help for.
]]

local function print_banner()
   util.printout("\nLuaRocks "..cfg.program_version..", the Lua package manager")
end

local function print_section(section)
   util.printout("\n"..section)
end

local function get_status(status)
   if status then
      return "ok"
   else
      return "not found"
   end
end

--- Driver function for the "help" command.
-- @param command string or nil: command to show help for; if not
-- given, help summaries for all commands are shown.
-- @return boolean or (nil, string): true if there were no errors
-- or nil and an error message if an invalid command was requested.
function help.command(flags, command)
   if not command then
      local conf = cfg.which_config()
      print_banner()
      print_section("NAME")
      util.printout("\t"..program..[[ - ]]..program_description)
      print_section("SYNOPSIS")
      util.printout("\t"..program..[[ [--from=<server> | --only-from=<server>] [--to=<tree>] [VAR=VALUE]... <command> [<argument>] ]])
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
	--local                Use the tree in the user's home directory.
	                       To enable it, see ']]..program..[[ help path'.
	--verbose              Display verbose output of commands executed.
	--timeout=<seconds>    Timeout on network operations, in seconds.
	                       0 means no timeout (wait forever).
	                       Default is ]]..tostring(cfg.connection_timeout)..[[.]])
      print_section("VARIABLES")
      util.printout([[
	Variables from the "variables" table of the configuration file
	can be overriden with VAR=VALUE assignments.]])
      print_section("COMMANDS")
      for name, command in util.sortedpairs(commands) do
         local cmd = require(command)
         util.printout("", name)
         util.printout("\t", cmd.help_summary)
      end
      print_section("CONFIGURATION")
      util.printout("\tLua version: " .. cfg.lua_version)
      util.printout("\tConfiguration files:")
      util.printout("\t\tSystem: ".. dir.normalize(conf.system.file) .. " (" .. get_status(conf.system.ok) ..")")
      if conf.user.file then
         util.printout("\t\tUser  : ".. dir.normalize(conf.user.file) .. " (" .. get_status(conf.user.ok) ..")\n")
      else
         util.printout("\t\tUser  : disabled in this LuaRocks installation.\n")
      end
      util.printout("\tRocks trees in use: ")
      for _, tree in ipairs(cfg.rocks_trees) do
      	if type(tree) == "string" then
      	   util.printout("\t\t"..dir.normalize(tree))
      	else
      	   local name = tree.name and " (\""..tree.name.."\")" or ""
      	   util.printout("\t\t"..dir.normalize(tree.root)..name)
      	end
      end
   else
      command = command:gsub("-", "_")
      local cmd = commands[command] and require(commands[command])
      if cmd then
         local arguments = cmd.help_arguments or "<argument>"
         print_banner()
         print_section("NAME")
         util.printout("\t"..program.." "..command.." - "..cmd.help_summary)
         print_section("SYNOPSIS")
         util.printout("\t"..program.." "..command.." "..arguments)
         print_section("DESCRIPTION")
         util.printout("",(cmd.help:gsub("\n","\n\t"):gsub("\n\t$","")))
         print_section("SEE ALSO")
         util.printout("","'"..program.." help' for general options and configuration.\n")
      else
         return nil, "Unknown command: "..command
      end
   end
   return true
end

return help
