
--- Module implementing the luarocks-admin "make_manifest" command.
-- Compile a manifest file for a repository.
local make_manifest = {}
package.loaded["luarocks.make_manifest"] = make_manifest

local manif = require("luarocks.manif")
local index = require("luarocks.index")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local deps = require("luarocks.deps")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")

util.add_run_function(make_manifest)
make_manifest.help_summary = "Compile a manifest file for a repository."

make_manifest.help = [[
<argument>, if given, is a local repository pathname.

--local-tree  If given, do not write versioned versions of the manifest file.
              Use this when rebuilding the manifest of a local rocks tree.
]]

--- Driver function for "make_manifest" command.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository configured as cfg.rocks_dir is used.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function make_manifest.command(flags, repo)
   assert(type(repo) == "string" or not repo)
   repo = repo or cfg.rocks_dir
  
   util.printout("Making manifest for "..repo)
   
   if repo:match("/lib/luarocks") and not flags["local-tree"] then
      util.warning("This looks like a local rocks tree, but you did not pass --local-tree.")
   end
   
   local ok, err = manif.make_manifest(repo, deps.get_deps_mode(flags), not flags["local-tree"])
   if ok and not flags["local-tree"] then
      util.printout("Generating index.html for "..repo)
      index.make_index(repo)
   end
   if flags["local-tree"] then
      for luaver in util.lua_versions() do
         fs.delete(dir.path(repo, "manifest-"..luaver))
      end
   end
   return ok, err
end

return make_manifest
