--- Module implementing the LuaRocks "list" command.
-- Lists currently installed rocks.

local list = {}

local luarocks = require("luarocks")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local cmd = require("luarocks.cmd")

list.help_summary = "List currently installed rocks."
list.help_arguments = "[--porcelain] <filter>"
list.help = [[
<filter> is a substring of a rock name to filter by.

--outdated    List only rocks for which there is a
              higher version available in the rocks server.

--porcelain   Produce machine-friendly output.
]]

local function list_outdated(outdated, porcelain)
   cmd.title("Outdated rocks:", porcelain)
   for _, item in ipairs(outdated) do
      if porcelain then
         cmd.printout(item.name, item.installed, item.available, item.repo)
      else
         cmd.printout(item.name)
         cmd.printout("   " .. item.installed .. " < " .. item.available .. " at " .. item.repo)
         cmd.printout()
      end
   end
   return true
end

--- Driver function for "list" command.
-- @param filter string or nil: A substring of a rock name to filter by.
-- @param version string or nil: a version may also be passed.
-- @return boolean: True if succeeded, nil on errors.
function list.command(flags, filter, version)
   local title = "Rocks installed for Lua " .. cfg.lua_version
   if flags["tree"] then
      title = title .. " in " .. flags["tree"]
   end

   local results, err = luarocks.list(filter, flags["outdated"], version, flags["tree"])
   if not results then return nil, err end
   
   if flags["outdated"] then
      return list_outdated(results, flags["porcelain"])
   end
   
   cmd.title(title, flags["porcelain"])
   cmd.print_result_tree(results, flags["porcelain"])

   return true
end

return list
