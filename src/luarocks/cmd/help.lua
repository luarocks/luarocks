
--- Module implementing the LuaRocks "help" command.
-- This is a generic help display module, which
-- uses a global table called "commands" to find commands
-- to show help for; each command should be represented by a
-- table containing "help" and "help_summary" fields.
local help = {}

local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local cmd = require("luarocks.cmd")

local program = util.this_program("luarocks")

help.help_summary = "Help on commands. Type '"..program.." help <command>' for more."

help.help_arguments = "[<command>]"
help.help = [[
<command> is the command to show help for.
]]

local function print_banner()
   cmd.printout("\nLuaRocks "..cfg.program_version..", the Lua package manager")
end

local function print_section(section)
   cmd.printout("\n"..section)
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
function help.command(description, commands, command)
   assert(type(description) == "string")
   assert(type(commands) == "table")

   if not command then
      local conf = cfg.which_config()
      print_banner()
      print_section("NAME")
      cmd.printout("\t"..program..[[ - ]]..description)
      print_section("SYNOPSIS")
      cmd.printout("\t"..program..[[ [<flags...>] [VAR=VALUE]... <command> [<argument>] ]])
      print_section("GENERAL OPTIONS")
      cmd.printout([[
	These apply to all commands, as appropriate:

	--dev                  Enable the sub-repositories in rocks servers
	                       for rockspecs of in-development versions
	--server=<server>      Fetch rocks/rockspecs from this server
	                       (takes priority over config file)
	--only-server=<server> Fetch rocks/rockspecs from this server only
	                       (overrides any entries in the config file)
	--only-sources=<url>   Restrict downloads to paths matching the
	                       given URL.
        --lua-dir=<prefix>     Which Lua installation to use.
	--tree=<tree>          Which tree to operate on.
	--local                Use the tree in the user's home directory.
	                       To enable it, see ']]..program..[[ help path'.
	--verbose              Display verbose output of commands executed.
	--timeout=<seconds>    Timeout on network operations, in seconds.
	                       0 means no timeout (wait forever).
	                       Default is ]]..tostring(cfg.connection_timeout)..[[.]])
      print_section("VARIABLES")
      cmd.printout([[
	Variables from the "variables" table of the configuration file
	can be overriden with VAR=VALUE assignments.]])
      print_section("COMMANDS")
      for name, modname in util.sortedpairs(commands) do
         cmd.printout("", name)
         cmd.printout("\t", cmd.help_summary)
      end
      print_section("CONFIGURATION")
      cmd.printout("\tLua version: " .. cfg.lua_version)
      if cfg.luajit_version then
         cmd.printout("\tLuaJIT version: " .. cfg.luajit_version)
      end
      cmd.printout()
      cmd.printout("\tConfiguration files:")
      cmd.printout("\t\tSystem  : ".. dir.normalize(conf.system.file) .. " (" .. get_status(conf.system.ok) ..")")
      if conf.user.file then
         cmd.printout("\t\tUser    : ".. dir.normalize(conf.user.file) .. " (" .. get_status(conf.user.ok) ..")")
      else
         cmd.printout("\t\tUser    : disabled in this LuaRocks installation.")
      end
      if conf.project then
         cmd.printout("\t\tProject : ".. dir.normalize(conf.project.file) .. " (" .. get_status(conf.project.ok) ..")")
      end
      cmd.printout()
      cmd.printout("\tRocks trees in use: ")
      for _, tree in ipairs(cfg.rocks_trees) do
         if type(tree) == "string" then
            cmd.printout("\t\t"..dir.normalize(tree))
         else
            local name = tree.name and " (\""..tree.name.."\")" or ""
            cmd.printout("\t\t"..dir.normalize(tree.root)..name)
         end
      end
      cmd.printout()
   else
      command = command:gsub("-", "_")
      local my_cmd = commands[command] and require(commands[command])
      if my_cmd then
         local arguments = my_cmd.help_arguments or "<argument>"
         print_banner()
         print_section("NAME")
         cmd.printout("\t"..program.." "..command.." - "..my_cmd.help_summary)
         print_section("SYNOPSIS")
         cmd.printout("\t"..program.." "..command.." "..arguments)
         print_section("DESCRIPTION")
         cmd.printout("",(my_cmd.help:gsub("\n","\n\t"):gsub("\n\t$","")))
         print_section("SEE ALSO")
         if my_cmd.help_see_also then
            cmd.printout(my_cmd.help_see_also)
         end
         cmd.printout("","'"..program.." help' for general options and configuration.\n")
      else
         return nil, "Unknown command: "..command
      end
   end
   return true
end

return help
