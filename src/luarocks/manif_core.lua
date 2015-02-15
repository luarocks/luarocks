
--- Core functions for querying manifest files.
-- This module requires no specific 'fs' functionality.
--module("luarocks.manif_core", package.seeall)
local manif_core = {}
package.loaded["luarocks.manif_core"] = manif_core

local persist = require("luarocks.persist")
local type_check = require("luarocks.type_check")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local path = require("luarocks.path")

manif_core.manifest_cache = {}

--- Back-end function that actually loads the manifest
-- and stores it in the manifest cache.
-- @param file string: The local filename of the manifest file.
-- @param repo_url string: The repository identifier.
-- @param quick boolean: If given, skips type checking.
function manif_core.manifest_loader(file, repo_url, quick)
   local manifest, err = persist.load_into_table(file)
   if not manifest then
      return nil, "Failed loading manifest for "..repo_url..": "..err
   end
   local globals = err
   if not quick then
      local ok, err = type_check.type_check_manifest(manifest, globals)
      if not ok then
         return nil, "Error checking manifest: "..err
      end
   end

   manif_core.manifest_cache[repo_url] = manifest
   return manifest
end

--- Load a local manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string): A table representing the manifest,
-- or nil followed by an error message.
function manif_core.load_local_manifest(repo_url)
   assert(type(repo_url) == "string")

   if manif_core.manifest_cache[repo_url] then
      return manif_core.manifest_cache[repo_url]
   end

   local pathname = dir.path(repo_url, "manifest")

   return manif_core.manifest_loader(pathname, repo_url, true)
end

--- Get all versions of a package listed in a manifest file.
-- @param name string: a package name.
-- @param deps_mode string: "one", to use only the currently
-- configured tree; "order" to select trees based on order
-- (use the current tree and all trees below it on the list)
-- or "all", to use all trees.
-- @return table: An array of strings listing installed
-- versions of a package.
function manif_core.get_versions(name, deps_mode)
   assert(type(name) == "string")
   assert(type(deps_mode) == "string")
   
   local manifest = {}
   path.map_trees(deps_mode, function(tree)
      local loaded = manif_core.load_local_manifest(path.rocks_dir(tree))
      if loaded then
         util.deep_merge(manifest, loaded)
      end
   end)
   
   local item = next(manifest) and manifest.repository[name]
   if item then
      return util.keys(item)
   end
   return {}
end

return manif_core
