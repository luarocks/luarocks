--- LuaRocks public programmatic API, version 3.0
local luarocks = {}

local cfg = require("luarocks.core.cfg")
local list = require("luarocks.cmd.list")
local search = require("luarocks.search")
local vers = require("luarocks.vers")
local util = require("luarocks.util")
local path = require("luarocks.path")

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

--- Return a table of installed rocks
function luarocks.list(filter, outdated, version, tree)
   local query = search.make_query(filter and filter:lower() or "", version)
   query.exact_name = false
   local trees = cfg.rocks_trees
   if tree then
     trees = { tree }
   end
   
   if outdated then
      return check_outdated(trees, query)
   end
   
   local results = {}
   for _, tree in ipairs(trees) do
     local ok, err, errcode = search.manifest_search(results, path.rocks_dir(tree), query)
     if not ok and errcode ~= "open" then
        util.warning(err)
     end
   end
   results = search.return_results(results)
   return results
end

return luarocks
