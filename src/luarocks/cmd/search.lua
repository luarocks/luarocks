--- Module implementing the LuaRocks "search" command.
-- Queries LuaRocks servers.
local cmd_search = {}

local cfg = require("luarocks.core.cfg")
local luarocks = require("luarocks")
local util = require("luarocks.util")
local cmd = require("luarocks.cmd")

cmd_search.help_summary = "Query the LuaRocks servers."
cmd_search.help_arguments = "[--source] [--binary] { <name> [<version>] | --all }"
cmd_search.help = [[
--source     Return only rockspecs and source rocks,
             to be used with the "build" command.
--binary     Return only pure Lua and binary rocks (rocks that can be used
             with the "install" command without requiring a C toolchain).
--all        List all contents of the server that are suitable to
             this platform, do not filter by name.
--porcelain  Return a machine readable format.
]]

--- Driver function for "search" command.
-- @param name string: A substring of a rock name to search.
-- @param version string or nil: a version may also be passed.
-- @return boolean or (nil, string): True if the search was successful; nil and an
-- error message otherwise.
function cmd_search.command(flags, name, version)
   name = util.adjust_name_and_namespace(name, flags)

   if flags["all"] then
      name = nil
   end

   if type(name) ~= "string" and not flags["all"] then
      return nil, "Enter name and version or use --all. " .. cmd.see_help("search")
   end
   
   local porcelain = flags["porcelain"]
   local full_name = (name or "") .. (version and " " .. version or "")
   cmd.title(full_name .. " - Search results for Lua " .. cfg.lua_version .. ":", porcelain, "=")

   local search_table, err = luarocks.search(name, version, (flags["source"] and "source") or (flags["binary"] and "binary")) 
   if not search_table then
      return nil, err
   end

   if search_table["sources"] and not flags["binary"] then
      cmd.title("Rockspecs and source rocks:", porcelain)
      cmd.print_result_tree(search_table["sources"], porcelain)
   end
   if search_table["binary"] and not flags["source"] then    
      cmd.title("Binary and pure-Lua rocks:", porcelain)
      cmd.print_result_tree(search_table["binary"], porcelain)
   end

   return true
end

return cmd_search
