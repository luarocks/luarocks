--- Module for handling manifest files and tables.
-- Manifest files describe the contents of a LuaRocks tree or server.
-- They are loaded into manifest tables, which are then used for
-- performing searches, matching dependencies, etc.
local manif = {}

local core = require("luarocks.core.manif")
local persist = require("luarocks.persist")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")
local path = require("luarocks.path")
local util = require("luarocks.util")
local type_manifest = require("luarocks.type.manifest")

manif.cache_manifest = core.cache_manifest

manif.rock_manifest_cache = {}

local function check_manifest(repo_url, manifest, globals)
   local ok, err = type_manifest.check(manifest, globals)
   if not ok then
      core.cache_manifest(repo_url, cfg.lua_version, nil)
      return nil, "Error checking manifest: "..err, "type"
   end
   return manifest
end

function manif.load_local_manifest(repo_url)
   local manifest, err, errcode = core.load_local_manifest(repo_url)
   if not manifest then
      return nil, err, errcode
   end
   if err then
      return check_manifest(repo_url, manifest, err)
   end
   return manifest
end

function manif.load_rock_manifest(name, version, root)
   assert(type(name) == "string")
   assert(type(version) == "string")

   local name_version = name.."/"..version
   if manif.rock_manifest_cache[name_version] then
      return manif.rock_manifest_cache[name_version].rock_manifest
   end
   local pathname = path.rock_manifest_file(name, version, root)
   local rock_manifest = persist.load_into_table(pathname)
   if not rock_manifest then
      return nil, "rock_manifest file not found for "..name.." "..version.." - not a LuaRocks tree?"
   end
   manif.rock_manifest_cache[name_version] = rock_manifest
   return rock_manifest.rock_manifest
end


local function fetch_manifest_from(repo_url, filename)
   local url = dir.path(repo_url, filename)
   local name = repo_url:gsub("[/:]","_")
   local cache_dir = dir.path(cfg.local_cache, name)
   local ok = fs.make_dir(cache_dir)
   if not ok then
      return nil, "Failed creating temporary cache directory "..cache_dir
   end
   local file, err, errcode = fetch.fetch_url(url, dir.path(cache_dir, filename), true)
   if not file then
      return nil, "Failed fetching manifest for "..repo_url..(err and " - "..err or ""), errcode
   end
   return file
end

--- Load a local or remote manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_local_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @return table or (nil, string, [string]): A table representing the manifest,
-- or nil followed by an error message and an optional error code.
function manif.load_manifest(repo_url, lua_version)
   assert(type(repo_url) == "string")
   assert(type(lua_version) == "string" or not lua_version)
   lua_version = lua_version or cfg.lua_version

   local cached_manifest = core.get_cached_manifest(repo_url, lua_version)
   if cached_manifest then
      return cached_manifest
   end

   local filenames = {
      "manifest-"..lua_version..".zip",
      "manifest-"..lua_version,
      "manifest",
   }

   local protocol, repodir = dir.split_url(repo_url)
   local pathname
   if protocol == "file" then
      for _, filename in ipairs(filenames) do
         pathname = dir.path(repodir, filename)
         if fs.exists(pathname) then
            break
         end
      end
   else
      local err, errcode
      for _, filename in ipairs(filenames) do
         pathname, err, errcode = fetch_manifest_from(repo_url, filename)
         if pathname then
            break
         end
      end
      if not pathname then 
         return nil, err, errcode
      end
   end
   if pathname:match(".*%.zip$") then
      pathname = fs.absolute_name(pathname)
      local dirname = dir.dir_name(pathname)
      fs.change_dir(dirname)
      local nozip = pathname:match("(.*)%.zip$")
      fs.delete(nozip)
      local ok = fs.unzip(pathname)
      fs.pop_dir()
      if not ok then
         fs.delete(pathname)
         fs.delete(pathname..".timestamp")
         return nil, "Failed extracting manifest file"
      end
      pathname = nozip
   end
   local manifest, err, errcode = core.manifest_loader(pathname, repo_url, lua_version)
   if not manifest then
      return nil, err, errcode
   end
   return check_manifest(repo_url, manifest, err)
end

--- Get type and name of an item (a module or a command) provided by a file.
-- @param deploy_type string: rock manifest subtree the file comes from ("bin", "lua", or "lib").
-- @param file_path string: path to the file relatively to deploy_type subdirectory.
-- @return (string, string): item type ("module" or "command") and name.
function manif.get_provided_item(deploy_type, file_path)
   assert(type(deploy_type) == "string")
   assert(type(file_path) == "string")
   local item_type = deploy_type == "bin" and "command" or "module"
   local item_name = item_type == "command" and file_path or path.path_to_module(file_path)
   return item_type, item_name
end

local function get_providers(item_type, item_name, repo)
   assert(type(item_type) == "string")
   assert(type(item_name) == "string")
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)
   local manifest = manif.load_local_manifest(rocks_dir)
   return manifest and manifest[item_type .. "s"][item_name]
end

--- Given a name of a module or a command, figure out which rock name and version
-- correspond to it in the rock tree manifest.
-- @param item_type string: "module" or "command".
-- @param item_name string: module or command name.
-- @param root string or nil: A local root dir for a rocks tree. If not given, the default is used.
-- @return (string, string) or nil: name and version of the provider rock or nil if there
-- is no provider.
function manif.get_current_provider(item_type, item_name, repo)
   local providers = get_providers(item_type, item_name, repo)
   if providers then
      return providers[1]:match("([^/]*)/([^/]*)")
   end
end

function manif.get_next_provider(item_type, item_name, repo)
   local providers = get_providers(item_type, item_name, repo)
   if providers and providers[2] then
      return providers[2]:match("([^/]*)/([^/]*)")
   end
end

--- Given a name of a module or a command provided by a package, figure out
-- which file provides it.
-- @param name string: package name.
-- @param version string: package version.
-- @param item_type string: "module" or "command".
-- @param item_name string: module or command name.
-- @param root string or nil: A local root dir for a rocks tree. If not given, the default is used.
-- @return (string, string): rock manifest subtree the file comes from ("bin", "lua", or "lib")
-- and path to the providing file relatively to that subtree.
function manif.get_providing_file(name, version, item_type, item_name, repo)
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)
   local manifest = manif.load_local_manifest(rocks_dir)

   local entry_table = manifest.repository[name][version][1]
   local file_path = entry_table[item_type .. "s"][item_name]

   if item_type == "command" then
      return "bin", file_path
   end

   -- A module can be in "lua" or "lib". Decide based on extension first:
   -- most likely Lua modules are in "lua/" and C modules are in "lib/".
   if file_path:match("%." .. cfg.lua_extension .. "$") then
      return "lua", file_path
   elseif file_path:match("%." .. cfg.lib_extension .. "$") then
      return "lib", file_path
   end

   -- Fallback to rock manifest scanning.
   local rock_manifest = manif.load_rock_manifest(name, version)
   local subtree = rock_manifest.lib

   for path_part in file_path:gmatch("[^/]+") do
      if type(subtree) == "table" then
         subtree = subtree[path_part]
      else
         -- Assume it's in "lua/" if it's not in "lib/".
         return "lua", file_path
      end
   end

   return type(subtree) == "string" and "lib" or "lua", file_path
end

--- Get all versions of a package listed in a manifest file.
-- @param name string: a package name.
-- @param deps_mode string: "one", to use only the currently
-- configured tree; "order" to select trees based on order
-- (use the current tree and all trees below it on the list)
-- or "all", to use all trees.
-- @return table: An array of strings listing installed
-- versions of a package.
function manif.get_versions(dep, deps_mode)
   assert(type(dep) == "table")
   assert(type(deps_mode) == "string")
   
   local name = dep.name
   local namespace = dep.namespace

   local version_set = {}
   path.map_trees(deps_mode, function(tree)
      local manifest = manif.load_local_manifest(path.rocks_dir(tree))

      if manifest and manifest.repository[name] then
         for version in pairs(manifest.repository[name]) do
            if dep.namespace then
               local ns_file = path.rock_namespace_file(name, version, tree)
               local fd = io.open(ns_file, "r")
               if fd then
                  local ns = fd:read("*a")
                  fd:close()
                  if ns == namespace then
                     version_set[version] = true
                  end
               end
            else
               version_set[version] = true
            end
         end
      end
   end)

   return util.keys(version_set)
end

return manif
