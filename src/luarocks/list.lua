
--- Module implementing the LuaRocks "list" command.
-- Lists currently installed rocks.
--module("luarocks.list", package.seeall)
local list = {}
package.loaded["luarocks.list"] = list

local search = require("luarocks.search")
local deps = require("luarocks.deps")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")

list.help_summary = "Lists currently installed rocks."
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
      search.manifest_search(results_installed, path.rocks_dir(tree), query)
   end
   local outdated = {}
   for name, versions in util.sortedpairs(results_installed) do
      local latest_installed
      local latest_available, latest_available_repo

      for version, _ in util.sortedpairs(versions) do
         latest_installed = version
         break
      end

      local query_available = search.make_query(name:lower())
      query.exact_name = true
      local results_available, err = search.search_repos(query_available)
      
      if results_available[name] then
         for version, repos in util.sortedpairs(results_available[name], deps.compare_versions) do
            latest_available = version
            for _, repo in ipairs(repos) do
               latest_available_repo = repo.repo
               break
            end
            break
         end
         
         if deps.compare_versions(latest_available, latest_installed) then
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
function list.run(...)
   local flags, filter, version = util.parse_flags(...)
   local query = search.make_query(filter and filter:lower() or "", version)
   query.exact_name = false
   local trees = cfg.rocks_trees
   if flags["tree"] then
      trees = { flags["tree"] }
   end
   
   if flags["outdated"] then
      return list_outdated(trees, query, flags["porcelain"])
   end
   
   local results = {}
   for _, tree in ipairs(trees) do
      local ok, err = search.manifest_search(results, path.rocks_dir(tree), query)
      if not ok then
         util.warning(err)
      end
   end
   util.title("Installed rocks:", flags["porcelain"])
   search.print_results(results, flags["porcelain"])
   return true
end

return list
