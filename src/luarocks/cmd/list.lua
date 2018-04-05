
--- Module implementing the LuaRocks "list" command.
-- Lists currently installed rocks.
local list = {}

local search = require("luarocks.search")
local queries = require("luarocks.queries")
local vers = require("luarocks.core.vers")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")

list.help_summary = "List currently installed rocks."
list.help_arguments = "[--porcelain] <filter>"
list.help = [[
<filter> is a substring of a rock name to filter by.

--outdated    List only rocks for which there is a
              higher version available in the rocks server.

--porcelain   Produce machine-friendly output.
]]

local function check_outdated(trees, query)
   local results_installed = {}
   for _, tree in ipairs(trees) do
      search.local_manifest_search(results_installed, path.rocks_dir(tree), query)
   end
   local outdated = {}
   for name, versions in util.sortedpairs(results_installed) do
      versions = util.keys(versions)
      table.sort(versions, vers.compare_versions)
      local latest_installed = versions[1]

      local query_available = queries.new(name:lower())
      local results_available, err = search.search_repos(query_available)
      
      if results_available[name] then
         local available_versions = util.keys(results_available[name])
         table.sort(available_versions, vers.compare_versions)
         local latest_available = available_versions[1]
         local latest_available_repo = results_available[name][latest_available][1].repo
         
         if vers.compare_versions(latest_available, latest_installed) then
            table.insert(outdated, { name = name, installed = latest_installed, available = latest_available, repo = latest_available_repo })
         end
      end
   end
   return outdated
end

local function list_outdated(trees, query, porcelain)
   util.title("Outdated rocks:", porcelain)
   local outdated = check_outdated(trees, query)
   for _, item in ipairs(outdated) do
      if porcelain then
         util.printout(item.name, item.installed, item.available, item.repo)
      else
         util.printout(item.name)
         util.printout("   "..item.installed.." < "..item.available.." at "..item.repo)
         util.printout()
      end
   end
   return true
end

--- Driver function for "list" command.
-- @param filter string or nil: A substring of a rock name to filter by.
-- @param version string or nil: a version may also be passed.
-- @return boolean: True if succeeded, nil on errors.
function list.command(flags, filter, version)
   local query = queries.new(filter and filter:lower() or "", version, true)
   local trees = cfg.rocks_trees
   if flags["tree"] then
      trees = { flags["tree"] }
   end
   
   if flags["outdated"] then
      return list_outdated(trees, query, flags["porcelain"])
   end
   
   local results = {}
   for _, tree in ipairs(trees) do
      local ok, err, errcode = search.local_manifest_search(results, path.rocks_dir(tree), query)
      if not ok and errcode ~= "open" then
         util.warning(err)
      end
   end
   util.title("Installed rocks for Lua "..cfg.lua_version..":", flags["porcelain"])
   search.print_result_tree(results, flags["porcelain"])
   return true
end

return list
