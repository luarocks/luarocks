
--- Module implementing an external command with legacy arg parsing.
local legacyexternalcommand = {}

local util = require("luarocks.util")

legacyexternalcommand.help_summary = "generate legacyexternalcommand package files of a rock."
legacyexternalcommand.help_arguments = "arg1 [arg2]"
legacyexternalcommand.help = [[
This addon generates legacyexternalcommand package files of a rock.
First argument is the name of a rock, the second argument is optional
and needed when legacyexternalcommand uses another name (usually prefixed by lua-).
Files are generated with the source content of the rock and more
especially the rockspec. So, the rock is downloaded and unpacked.
]]

--- Driver function for the "legacyexternalcommand" command.
-- @param arg1 string: arg1.
-- @param arg2 string: arg2 (optional)
-- @return boolean: true if successful
function legacyexternalcommand.command(flags, arg1, arg2)
   if type(arg1) ~= 'string' then
      return nil, "Argument missing. "..util.see_help('legacyexternalcommand')
   end

   for k,v in pairs(flags) do
      print("FLAGS", k,v)
   end
   print("ARG1", tostring(arg1))
   print("ARG2", tostring(arg2))
   return true
end

return legacyexternalcommand
