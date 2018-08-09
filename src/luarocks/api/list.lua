local list_api = {}

local config_api = require("luarocks.api.config")
local cfg = require("luarocks.core.cfg")
local path = require("luarocks.path")
local queries = require("luarocks.queries")
local search = require("luarocks.search")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")

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
      if not results_available then return nil, err end

      if results_available[name] then
         local available_versions = util.keys(results_available[name])
         table.sort(available_versions, vers.compare_versions)
         local latest_available = available_versions[1]
         local latest_available_repo = results_available[name][latest_available][1].repo

         if vers.compare_versions(latest_available, latest_installed) then
            table.insert(outdated, {
               name = name,
               installed = latest_installed,
               available = latest_available,
               repo = latest_available_repo
            })
         end
      end
   end

   return outdated
end

function list_api.list(filter, outdated, version, tree)
   config_api.set_rock_tree(tree)

   local query = queries.new(filter and filter:lower() or "", version, true)

   local trees = cfg.rocks_trees
   if tree then
      trees = { tree }
   end

   if outdated then
      return check_outdated(trees, query)
   end

   local results = {}
   for _, tree in ipairs(trees) do
      local ok, err, errcode = search.local_manifest_search(results, path.rocks_dir(tree), query)
      if not ok and errcode ~= "open" then
         return nil, err, errcode
      end
   end

   return results 
end

return list_api
