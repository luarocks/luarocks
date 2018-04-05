
--- Module implementing the LuaRocks "pack" command.
-- Creates a rock, packing sources or binaries.
local cmd_pack = {}

local util = require("luarocks.util")
local pack = require("luarocks.pack")

cmd_pack.help_summary = "Create a rock, packing sources or binaries."
cmd_pack.help_arguments = "{<rockspec>|<name> [<version>]}"
cmd_pack.help = [[
Argument may be a rockspec file, for creating a source rock,
or the name of an installed package, for creating a binary rock.
In the latter case, the app version may be given as a second
argument.
]]

--- Driver function for the "pack" command.
-- @param arg string:  may be a rockspec file, for creating a source rock,
-- or the name of an installed package, for creating a binary rock.
-- @param version string or nil: if the name of a package is given, a
-- version may also be passed.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
function cmd_pack.command(flags, arg, version)
   assert(type(version) == "string" or not version)
   if type(arg) ~= "string" then
      return nil, "Argument missing. "..util.see_help("pack")
   end

   local file, err
   if arg:match(".*%.rockspec") then
      file, err = pack.pack_source_rock(arg)
   else
      local name = util.adjust_name_and_namespace(arg, flags)
      file, err = pack.pack_installed_rock(name, version, flags["tree"])
   end
   if err then
      return nil, err
   else
      util.printout("Packed: "..file)
      return true
   end
end

return cmd_pack
