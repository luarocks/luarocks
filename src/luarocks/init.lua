--- LuaRocks public programmatic API, version 3.0
local luarocks = {}

local cfg = require("luarocks.core.cfg")
local list = require("luarocks.cmd.list")

--- Obtain version of LuaRocks and its API.
-- @return (string, string) Full version of this LuaRocks instance
-- (in "x.y.z" format for releases, or "dev" for a checkout of
-- in-development code), and the API version, in "x.y" format.
function luarocks.version()
   return cfg.program_version, cfg.program_series
end

--- Return 1
function luarocks.test_func()
	return 1
end

--- Print the list of installed rocks
--local list = require("luarocks.cmd.list")
--flags = {}
--function luarocks.list(flags)
--	list.command(flags)
--end


local search = require("luarocks.search")
local vers = require("luarocks.vers")
--local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")


--- Return a table of installed rocks
function luarocks.list(...)

	---[[ here there should be a function that parses the ... into flags, filter, version]]

	--- hardcode flags empty for now
	flags = {}

	local query = search.make_query(filter and filter:lower() or "", version)
	query.exact_name = false
	local trees = cfg.rocks_trees
	if flags["tree"] then
	  trees = { flags["tree"] }
	end

	--if flags["outdated"] then
	--   return list_outdated(trees, query, flags["porcelain"])
	--end

	local results = {}
	for _, tree in ipairs(trees) do
	  local ok, err, errcode = search.manifest_search(results, path.rocks_dir(tree), query)
	  if not ok and errcode ~= "open" then
	     util.warning(err)
	  end
	end

	--util.title("Installed rocks:", flags["porcelain"])
	--results = search.return_results(results, flags["porcelain"])

	--- hardcoding flags["porcelain"] to true
	results = search.return_results(results, true)
	return results
end

return luarocks
