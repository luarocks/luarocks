
--- Core functions for querying manifest files.
-- This module requires no specific 'fs' functionality.
module("luarocks.manif_core", package.seeall)

local persist = require("luarocks.persist")
local type_check = require("luarocks.type_check")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")

manifest_cache = {}

--- Back-end function that actually loads the manifest
-- and stores it in the manifest cache.
-- @param file string: The local filename of the manifest file.
-- @param repo_url string: The repository identifier.
function manifest_loader(file, repo_url, quick)
   local manifest = persist.load_into_table(file)
   if not manifest then
      return nil, "Failed loading manifest for "..repo_url
   end
   if not quick then
      local ok, err = type_check.type_check_manifest(manifest)
      if not ok then
         return nil, "Error checking manifest: "..err
      end
   end

   manifest_cache[repo_url] = manifest
   return manifest
end

--- Load a local manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string): A table representing the manifest,
-- or nil followed by an error message.
function load_local_manifest(repo_url)
   assert(type(repo_url) == "string")

   if manifest_cache[repo_url] then
      return manifest_cache[repo_url]
   end

   local pathname = dir.path(repo_url, "manifest")

   return manifest_loader(pathname, repo_url, true)
end

--- Get all versions of a package listed in a manifest file.
-- @param name string: a package name.
-- @param manifest table or nil: a manifest table; if not given, the
-- default local manifest table is used.
-- @return table: An array of strings listing installed
-- versions of a package.
function get_versions(name, manifest)
   assert(type(name) == "string")
   assert(type(manifest) == "table" or not manifest)
   
   if not manifest then
      manifest = load_local_manifest(cfg.rocks_dir)
      if not manifest then
         return {}
      end
   end
   
   local item = manifest.repository[name]
   if item then
      return util.keys(item)
   end
   return {}
end
