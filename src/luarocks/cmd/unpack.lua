--- Module implementing the LuaRocks "unpack" command.
-- Unpack the contents of a rock.
local unpack = {}

local cmd = require("luarocks.cmd")
local luarocks = require("luarocks")
local util = require("luarocks.util")

unpack.help_summary = "Unpack the contents of a rock."
unpack.help_arguments = "[--force] {<rock>|<name> [<version>]}"
unpack.help = [[
Unpacks the contents of a rock in a newly created directory.
Argument may be a rock file, or the name of a rock in a rocks server.
In the latter case, the app version may be given as a second argument.

--force   Unpack files even if the output directory already exists.
]]

--- Driver function for the "unpack" command.
-- @param ns_name string: may be a rock filename, for unpacking a 
-- rock file or the name of a rock to be fetched and unpacked.
-- @param version string or nil: if the name of a package is given, a
-- version may also be passed.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
function unpack.command(flags, ns_name, version)
   assert(type(version) == "string" or not version)
   
   if type(ns_name) ~= "string" then
      return nil, "Argument missing. " .. cmd.see_help("unpack")
   end

   ns_name = util.adjust_name_and_namespace(ns_name, flags)

   local kind, err, srcdir = luarocks.unpack(ns_name, flags["force"])
   if not kind then
      return nil, err
   end

   if kind == "src" or kind == "rockspec" then
      cmd.printout()
      cmd.printout("Done. You may now enter directory ")
      cmd.printout(srcdir)
      cmd.printout("and type 'luarocks make' to build.")
   end

   return true
end

return unpack
