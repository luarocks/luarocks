
--- Module implementing the LuaRocks "list" command.
-- Lists currently installed rocks.
module("luarocks.list", package.seeall)

local search = require("luarocks.search")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")

help_summary = "Lists currently installed rocks."

help = [[
<argument> is a substring of a rock name to filter by.
]]

--- Driver function for "list" command.
-- @param filter string or nil: A substring of a rock name to filter by.
-- @param version string or nil: a version may also be passed.
-- @return boolean: True if succeeded, nil on errors.
function run(...)
   local flags, filter, version = util.parse_flags(...)
   local results = {}
   local query = search.make_query(filter and filter:lower() or "", version)
   query.exact_name = false
   for _, tree in ipairs(cfg.rocks_trees) do
      search.manifest_search(results, path.rocks_dir(tree), query)
   end
   util.printout()
   util.printout("Installed rocks:")
   util.printout("----------------")
   util.printout()
   search.print_results(results, false)
   return true
end
