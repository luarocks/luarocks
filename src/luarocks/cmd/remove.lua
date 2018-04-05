
--- Module implementing the LuaRocks "remove" command.
-- Uninstalls rocks.
local cmd_remove = {}

local remove = require("luarocks.remove")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")
local search = require("luarocks.search")
local path = require("luarocks.path")
local deps = require("luarocks.deps")
local writer = require("luarocks.manif.writer")
local queries = require("luarocks.queries")

cmd_remove.help_summary = "Uninstall a rock."
cmd_remove.help_arguments = "[--force|--force-fast] <name> [<version>]"
cmd_remove.help = [[
Argument is the name of a rock to be uninstalled.
If a version is not given, try to remove all versions at once.
Will only perform the removal if it does not break dependencies.
To override this check and force the removal, use --force.
To perform a forced removal without reporting dependency issues,
use --force-fast.

]]..util.deps_mode_help()

--- Driver function for the "remove" command.
-- @param name string: name of a rock. If a version is given, refer to
-- a specific version; otherwise, try to remove all versions.
-- @param version string: When passing a package name, a version number
-- may also be given.
-- @return boolean or (nil, string, exitcode): True if removal was
-- successful, nil and an error message otherwise. exitcode is optionally returned.
function cmd_remove.command(flags, name, version)
   if type(name) ~= "string" then
      return nil, "Argument missing. "..util.see_help("remove")
   end

   name = util.adjust_name_and_namespace(name, flags)
   
   local deps_mode = flags["deps-mode"] or cfg.deps_mode
   
   local ok, err = fs.check_command_permissions(flags)
   if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end
   
   local rock_type = name:match("%.(rock)$") or name:match("%.(rockspec)$")
   local filename = name
   if rock_type then
      name, version = path.parse_name(filename)
      if not name then return nil, "Invalid "..rock_type.." filename: "..filename end
   end

   local results = {}
   name = name:lower()
   search.local_manifest_search(results, cfg.rocks_dir, queries.new(name, version))
   if not results[name] then
      return nil, "Could not find rock '"..name..(version and " "..version or "").."' in "..path.rocks_tree_to_string(cfg.root_dir)
   end

   local ok, err = remove.remove_search_results(results, name, deps_mode, flags["force"], flags["force-fast"])
   if not ok then
      return nil, err
   end

   writer.check_dependencies(nil, deps.get_deps_mode(flags))
   return true
end

return cmd_remove
