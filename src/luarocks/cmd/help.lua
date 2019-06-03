
--- Module implementing the LuaRocks "help" command.
-- This is a generic help display module, which
-- uses a global table called "commands" to find commands
-- to show help for; each command should be represented by a
-- table containing "help" and "help_summary" fields.
local help = {}

local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")

local program = util.this_program("luarocks")

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
function help.command(description, commands, command)
   assert(type(description) == "string")
   assert(type(commands) == "table")

   if not command then
      print_banner()
      print_section("NAME")
      util.printout("\t"..program..[[ - ]]..description)
      print_section("SYNOPSIS")
      util.printout("\t"..program..[[ [<flags...>] [VAR=VALUE]... <command> [<argument>] ]])
      print_section("GENERAL OPTIONS")
      util.printout([[
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
	--lua-version=<ver>    Which Lua version to use.
	--tree=<tree>          Which tree to operate on.
	--local                Use the tree in the user's home directory.
	                       To enable it, see ']]..program..[[ help path'.
	--global               Use the system tree when `local_by_default` is `true`.
	--verbose              Display verbose output of commands executed.
	--timeout=<seconds>    Timeout on network operations, in seconds.
	                       0 means no timeout (wait forever).
	                       Default is ]]..tostring(cfg.connection_timeout)..[[.]])
      print_section("VARIABLES")
      util.printout([[
	Variables from the "variables" table of the configuration file
	can be overridden with VAR=VALUE assignments.]])
      print_section("COMMANDS")
      for name, modname in util.sortedpairs(commands) do
         local cmd = require(modname)
         util.printout("", name)
         util.printout("\t", cmd.help_summary)
      end
      print_section("CONFIGURATION")
      util.printout("\tLua version: " .. cfg.lua_version)
      if cfg.luajit_version then
         util.printout("\tLuaJIT version: " .. cfg.luajit_version)
      end
      util.printout()
      util.printout("\tConfiguration files:")
      local conf = cfg.config_files
      util.printout("\t\tSystem  : ".. fs.absolute_name(conf.system.file) .. " (" .. get_status(conf.system.found) ..")")
      if conf.user.file then
         util.printout("\t\tUser    : ".. fs.absolute_name(conf.user.file) .. " (" .. get_status(conf.user.found) ..")")
      else
         util.printout("\t\tUser    : disabled in this LuaRocks installation.")
      end
      if conf.project then
         util.printout("\t\tProject : ".. fs.absolute_name(conf.project.file) .. " (" .. get_status(conf.project.found) ..")")
      end
      util.printout()
      util.printout("\tRocks trees in use: ")
      for _, tree in ipairs(cfg.rocks_trees) do
         if type(tree) == "string" then
            util.printout("\t\t"..fs.absolute_name(tree))
         else
            local name = tree.name and " (\""..tree.name.."\")" or ""
            util.printout("\t\t"..fs.absolute_name(tree.root)..name)
         end
      end
      util.printout()
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
         if cmd.help_see_also then
            util.printout(cmd.help_see_also)
         end
         util.printout("","'"..program.." help' for general options and configuration.\n")
      else
         return nil, "Unknown command: "..command
      end
   end
   return true
end

return help
