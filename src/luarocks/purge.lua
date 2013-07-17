
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
local remove = require("luarocks.remove")

help_summary = "Remove all installed rocks from a tree."
help_arguments = "--tree=<tree> [--old-versions]"
help = [[
This command removes rocks en masse from a given tree.
By default, it removes all rocks from a tree.

The --tree argument is mandatory: luarocks purge does not
assume a default tree.

--old-versions  Keep the highest-numbered version of each
                rock and remove the other ones. By default
                it only removes old versions if they are
                not needed as dependencies. This can be
                overridden with the flag --force.
]]

function run(...)
   local flags = util.parse_flags(...)
   
   local tree = flags["tree"]

   if type(tree) ~= "string" then
      return nil, "The --tree argument is mandatory. "..util.see_help("purge")
   end
   
   local results = {}
   local query = search.make_query("")
   query.exact_name = false
   search.manifest_search(results, path.rocks_dir(tree), query)

   local sort = function(a,b) return deps.compare_versions(b,a) end
   if flags["old-versions"] then
      sort = deps.compare_versions
   end

   for package, versions in util.sortedpairs(results) do
      for version, repositories in util.sortedpairs(versions, sort) do
         if flags["old-versions"] then
            util.printout("Keeping "..package.." "..version.."...")
            local ok, err = remove.remove_other_versions(package, version, flags["force"])
            if not ok then
               util.printerr(err)
            end
            break
         else
            util.printout("Removing "..package.." "..version.."...")
            local ok, err = repos.delete_version(package, version, true)
            if not ok then
               util.printerr(err)
            end
         end
      end
   end
   return manif.make_manifest(cfg.rocks_dir, "one")
end
