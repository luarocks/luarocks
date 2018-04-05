
--- Module implementing the LuaRocks "purge" command.
-- Remove all rocks from a given tree.
local purge = {}

local util = require("luarocks.util")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local search = require("luarocks.search")
local vers = require("luarocks.core.vers")
local repos = require("luarocks.repos")
local writer = require("luarocks.manif.writer")
local cfg = require("luarocks.core.cfg")
local remove = require("luarocks.remove")
local queries = require("luarocks.queries")

purge.help_summary = "Remove all installed rocks from a tree."
purge.help_arguments = "--tree=<tree> [--old-versions]"
purge.help = [[
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

function purge.command(flags)
   local tree = flags["tree"]

   if type(tree) ~= "string" then
      return nil, "The --tree argument is mandatory. "..util.see_help("purge")
   end
   
   local results = {}
   if not fs.is_dir(tree) then
      return nil, "Directory not found: "..tree
   end

   local ok, err = fs.check_command_permissions(flags)
   if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end

   search.local_manifest_search(results, path.rocks_dir(tree), queries.all())

   local sort = function(a,b) return vers.compare_versions(b,a) end
   if flags["old-versions"] then
      sort = vers.compare_versions
   end

   for package, versions in util.sortedpairs(results) do
      for version, _ in util.sortedpairs(versions, sort) do
         if flags["old-versions"] then
            util.printout("Keeping "..package.." "..version.."...")
            local ok, err = remove.remove_other_versions(package, version, flags["force"], flags["force-fast"])
            if not ok then
               util.printerr(err)
            end
            break
         else
            util.printout("Removing "..package.." "..version.."...")
            local ok, err = repos.delete_version(package, version, "none", true)
            if not ok then
               util.printerr(err)
            end
         end
      end
   end
   return writer.make_manifest(cfg.rocks_dir, "one")
end

return purge
