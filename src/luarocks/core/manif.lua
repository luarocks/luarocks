
--- Core functions for querying manifest files.
local manif = {}

local persist = require("luarocks.core.persist")
local type_check = require("luarocks.core.type_check")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.core.dir")
local require = nil
--------------------------------------------------------------------------------

-- Table with repository identifiers as keys and tables mapping
-- Lua versions to cached loaded manifests as values.
local manifest_cache = {}

--- Cache a loaded manifest.
-- @param repo_url string: The repository identifier.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @param manifest table: the manifest to be cached.
function manif.cache_manifest(repo_url, lua_version, manifest)
   lua_version = lua_version or cfg.lua_version
   manifest_cache[repo_url] = manifest_cache[repo_url] or {}
   manifest_cache[repo_url][lua_version] = manifest
end

--- Attempt to get cached loaded manifest.
-- @param repo_url string: The repository identifier.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @return table or nil: loaded manifest or nil if cache is empty.
function manif.get_cached_manifest(repo_url, lua_version)
   lua_version = lua_version or cfg.lua_version
   return manifest_cache[repo_url] and manifest_cache[repo_url][lua_version]
end

--- Back-end function that actually loads the manifest
-- and stores it in the manifest cache.
-- @param file string: The local filename of the manifest file.
-- @param repo_url string: The repository identifier.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @param quick boolean: If given, skips type checking.
-- @return table or (nil, string, string): the manifest or nil,
-- error message and error code ("open", "load", "run" or "type").
function manif.manifest_loader(file, repo_url, lua_version, quick)
   local manifest, err, errcode = persist.load_into_table(file)
   if not manifest then
      return nil, "Failed loading manifest for "..repo_url..": "..err, errcode
   end
   local globals = err
   if not quick then
      local ok, err = type_check.type_check_manifest(manifest, globals)
      if not ok then
         return nil, "Error checking manifest: "..err, "type"
      end
   end

   manif.cache_manifest(repo_url, lua_version, manifest)
   return manifest
end

--- Load a local manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string, string): A table representing the manifest,
-- or nil followed by an error message and an error code, see manifest_loader.
function manif.load_local_manifest(repo_url)
   assert(type(repo_url) == "string")

   local cached_manifest = manif.get_cached_manifest(repo_url)
   if cached_manifest then
      return cached_manifest
   end

   local pathname = dir.path(repo_url, "manifest")
   return manif.manifest_loader(pathname, repo_url, nil, true)
end

return manif
