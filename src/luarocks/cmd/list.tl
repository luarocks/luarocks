
--- Module implementing the LuaRocks "list" command.
-- Lists currently installed rocks.
local record list
   record Outdated
      name: string
      installed: string
      available: string
      repo: string
   end
end

local search = require("luarocks.search")
local queries = require("luarocks.queries")
local vers = require("luarocks.core.vers")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")

local type Outdated = list.Outdated

local type Parser = require("luarocks.vendor.argparse").Parser

local type Args = require("luarocks.core.types.args").Args

local type Tree = require("luarocks.core.types.tree").Tree

local type Query = require("luarocks.core.types.query").Query

function list.add_to_parser(parser: Parser)
   local cmd = parser:command("list", "List currently installed rocks.", util.see_also())

   cmd:argument("filter", "A substring of a rock name to filter by.")
      :args("?")
   cmd:argument("version", "Rock version to filter by.")
      :args("?")

   cmd:flag("--outdated", "List only rocks for which there is a higher "..
      "version available in the rocks server.")
   cmd:flag("--porcelain", "Produce machine-friendly output.")
end

local function check_outdated(trees: {string | Tree}, query: Query): {Outdated}
   local results_installed = {}
   for _, tree in ipairs(trees) do
      search.local_manifest_search(results_installed, path.rocks_dir(tree), query)
   end
   local outdated: {Outdated} = {}
   for name, versions in util.sortedpairs(results_installed) do
      local versionsk = util.keys(versions)
      table.sort(versionsk, vers.compare_versions)
      local latest_installed = versionsk[1]

      local query_available = queries.new(name:lower())
      local results_available = search.search_repos(query_available)

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

local function list_outdated(trees: {string | Tree}, query: Query, porcelain: boolean): boolean
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
-- @return boolean: True if succeeded, nil on errors.
function list.command(args: Args): boolean, string
   local query = queries.new(args.filter and args.filter:lower() or "", args.namespace, args.version, true)
   local trees = cfg.rocks_trees
   local title = "Rocks installed for Lua "..cfg.lua_version
   if args.tree then
      trees = { args.tree }
      title = title .. " in " .. args.tree
   end

   if args.outdated then
      return list_outdated(trees, query, args.porcelain)
   end

   local results = {}
   for _, tree in ipairs(trees) do
      local ok, err, errcode = search.local_manifest_search(results, path.rocks_dir(tree), query)
      if not ok and errcode ~= "open" then
         util.warning(err)
      end
   end
   util.title(title, args.porcelain)
   search.print_result_tree(results, args.porcelain)
   return true
end

return list
