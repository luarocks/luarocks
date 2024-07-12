

local persist = require("luarocks.core.persist")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.core.dir")
local util = require("luarocks.core.util")
local vers = require("luarocks.core.vers")
local path = require("luarocks.core.path")

local type Constraints = vers.Constraints

--- Core functions for querying manifest files.
local record manif
   
   record DependencyVersion
      constraints: {Constraints}
      name: string
   end
   
   record Manifest
      arch: string
      commands: {string: {string}}
      dependencies: {string: {string: {DependencyVersion}}}
      modules: {string: {string}}
      repository: {string: {string: Manifest}}
   end
   
   record Tree_manifest
      tree: cfg.Tree
      manifest: Manifest
   end
end

--------------------------------------------------------------------------------
 
local type DependencyVersion = manif.DependencyVersion
local type Manifest = manif.Manifest
local type Tree_manifest = manif.Tree_manifest



-- Table with repository identifiers as keys and tables mapping
-- Lua versions to cached loaded manifests as values.
local manifest_cache: Manifest = {}

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
function manif.get_cached_manifest(repo_url: string, lua_version: string): Manifest
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
function manif.manifest_loader(file: string, repo_url: string, lua_version: string): Manifest, string, string
   local manifest, err, errcode: {any: any}, {any: any} | string, string = persist.load_into_table(file)
   if not manifest then
      return nil, "Failed loading manifest for "..repo_url..": " ..tostring(err), errcode
   end
   
   manif.cache_manifest(repo_url, lua_version, manifest as Manifest) -- No runtime check if manifest is actually a Manifest!
   return manifest as Manifest, nil, nil
end

--- Load a local manifest describing a repository.
-- This is used by the luarocks.loader only.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string, string): A table representing the manifest,
-- or nil followed by an error message and an error code, see manifest_loader.
function manif.fast_load_local_manifest(repo_url: string): Manifest | nil, string, string 
   assert(type(repo_url) == "string")

   local cached_manifest = manif.get_cached_manifest(repo_url)
   if cached_manifest then
      return cached_manifest
   end

   local pathname = dir.path(repo_url, "manifest")
   return manif.manifest_loader(pathname, repo_url, nil)
end

function manif.load_rocks_tree_manifests(deps_mode: string): {Tree_manifest}
   local trees = {}
   path.map_trees(deps_mode, function(tree: cfg.Tree)
      local manifest= manif.fast_load_local_manifest(path.rocks_dir(tree))
      if manifest then
         table.insert(trees, {tree=tree, manifest=manifest})
      end
   end)
   return trees
end

function manif.scan_dependencies(name: string, version: string, tree_manifests: {Tree_manifest}, dest: {any: any})
   if dest[name] then
      return
   end
   dest[name] = version

   for _, tree in ipairs(tree_manifests) do
      local manifest = tree.manifest

      local pkgdeps: {DependencyVersion}
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
