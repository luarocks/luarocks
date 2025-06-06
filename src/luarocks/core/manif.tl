
--- Core functions for querying manifest files.
local record manif
end

local persist = require("luarocks.core.persist")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.core.dir")
local util = require("luarocks.core.util")
local vers = require("luarocks.core.vers")
local path = require("luarocks.core.path")

--------------------------------------------------------------------------------

local type Tree = require("luarocks.core.types.tree").Tree

local type Query = require("luarocks.core.types.query").Query

local type Manifest = require("luarocks.core.types.manifest").Manifest
local type Tree_manifest = require("luarocks.core.types.manifest").Tree_manifest



-- Table with repository identifiers as keys and tables mapping
-- Lua versions to cached loaded manifests as values.
local manifest_cache: {string: {string: Manifest}} = {}

--- Cache a loaded manifest.
-- @param repo_url string: The repository identifier.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @param manifest table: the manifest to be cached.
function manif.cache_manifest(repo_url: string, lua_version: string, manifest: Manifest)
   lua_version = lua_version or cfg.lua_version
   manifest_cache[repo_url] = manifest_cache[repo_url] or {}
   manifest_cache[repo_url][lua_version] = manifest
end

--- Attempt to get cached loaded manifest.
-- @param repo_url string: The repository identifier.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @return table or nil: loaded manifest or nil if cache is empty.
function manif.get_cached_manifest(repo_url: string, lua_version?: string): Manifest
   lua_version = lua_version or cfg.lua_version
   return manifest_cache[repo_url] and manifest_cache[repo_url][lua_version]
end

--- Back-end function that actually loads the manifest
-- and stores it in the manifest cache.
-- @param file string: The local filename of the manifest file.
-- @param repo_url string: The repository identifier.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @return table or (nil, string, string): the manifest or nil,
-- error message and error code ("open", "load", "run").
function manif.manifest_loader(file: string, repo_url: string, lua_version: string): Manifest, string | {any: any}, string
   local manifest, err, errcode: {string: any}, {string: boolean} | string, string

   if file:match(".*%.json$") then
      manifest, err, errcode = persist.load_json_into_table(file)
   else
      manifest, err, errcode = persist.load_into_table(file)
   end

   if not manifest and err is string then
      return nil, "Failed loading manifest for "..repo_url..": " .. err, errcode
   end

   manif.cache_manifest(repo_url, lua_version, manifest as Manifest) -- No runtime check if manifest is actually a Manifest!
   return manifest as Manifest, err, errcode
end

--- Load a local manifest describing a repository.
-- This is used by the luarocks.loader only.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string, string): A table representing the manifest,
-- or nil followed by an error message and an error code, see manifest_loader.
function manif.fast_load_local_manifest(repo_url: string): Manifest, string | {any: any}, string 

   local cached_manifest = manif.get_cached_manifest(repo_url)
   if cached_manifest then
      return cached_manifest
   end

   local pathname = dir.path(repo_url, "manifest")
   return manif.manifest_loader(pathname, repo_url, nil)
end

function manif.load_rocks_tree_manifests(deps_mode?: string): {Tree_manifest}
   local trees = {}
   path.map_trees(deps_mode, function(tree: Tree)
      local manifest= manif.fast_load_local_manifest(path.rocks_dir(tree))
      if manifest then
         table.insert(trees, {tree=tree, manifest=manifest})
      end
   end)
   return trees
end

function manif.scan_dependencies(name: string, version: string, tree_manifests: {Tree_manifest}, dest: {string: string})
   if dest[name] then
      return
   end
   dest[name] = version

   for _, tree in ipairs(tree_manifests) do
      local manifest = tree.manifest

      local pkgdeps: {Query}
      if manifest.dependencies and manifest.dependencies[name] then
         pkgdeps = manifest.dependencies[name][version]
      end
      if pkgdeps then
         for _, dep in ipairs(pkgdeps) do
            local pkg, constraints = dep.name, dep.constraints

            for _, t in ipairs(tree_manifests) do
               local entries = t.manifest.repository[pkg]
               if entries then
                  for ver, _ in util.sortedpairs(entries, vers.compare_versions) do
                     if (not constraints) or vers.match_constraints(vers.parse_version(ver), constraints) then
                        manif.scan_dependencies(pkg, ver, tree_manifests, dest)
                     end
                  end
               end
            end
         end
         return
      end
   end
end

return manif
