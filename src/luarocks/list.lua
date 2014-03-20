
--- Module implementing the LuaRocks "list" command.
-- Lists currently installed rocks.
--module("luarocks.list", package.seeall)
local list = {}
package.loaded["luarocks.list"] = list

local search = require("luarocks.search")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")

list.help_summary = "Lists currently installed rocks."
list.help_arguments = "[--porcelain] <filter>"
list.help = [[
<filter> is a substring of a rock name to filter by.

--porcelain   Produce machine-friendly output.
]]

--- Driver function for "list" command.
-- @param filter string or nil: A substring of a rock name to filter by.
-- @param version string or nil: a version may also be passed.
-- @return boolean: True if succeeded, nil on errors.
function list.run(...)
   local flags, filter, version = util.parse_flags(...)
   local results = {}
   local query = search.make_query(filter and filter:lower() or "", version)
   query.exact_name = false
   local trees = cfg.rocks_trees
   if flags["tree"] then
      trees = { flags["tree"] }
   end
   for _, tree in ipairs(trees) do
      search.manifest_search(results, path.rocks_dir(tree), query)
   end
   util.title("Installed rocks:", flags["porcelain"])
   search.print_results(results, flags["porcelain"])
   return true
end

return list
