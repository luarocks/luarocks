
--- Module implementing the LuaRocks "purge" command.
-- Remove all rocks from a given tree.
module("luarocks.purge", package.seeall)

local util = require("luarocks.util")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local search = require("luarocks.search")
local deps = require("luarocks.deps")
local repos = require("luarocks.repos")
local manif = require("luarocks.manif")
local cfg = require("luarocks.cfg")

help_summary = "Remove all installed rocks from a tree."
help_arguments = "--tree=<tree>"
help = [[
This command removes all rocks from a given tree. 

The --tree argument is mandatory: luarocks purge does not
assume a default tree.
]]

function run(...)
   local flags = util.parse_flags(...)
   
   local tree = flags["tree"]

   if type(tree) ~= "string" then
      return nil, "The --tree argument is mandatory, see help."
   end
   
   local results = {}
   local query = search.make_query("")
   query.exact_name = false
   search.manifest_search(results, path.rocks_dir(tree), query)

   for package, versions in util.sortedpairs(results) do
      for version, repositories in util.sortedpairs(versions, function(a,b) return deps.compare_versions(b,a) end) do
         util.printout("Removing "..package.." "..version.."...")
         local ok, err = repos.delete_version(package, version, true)
         if not ok then
            util.printerr(err) 
         end
      end
   end
   return manif.make_manifest(cfg.rocks_dir, "one")
end
