--- Module for handling manifest files and tables.
-- Manifest files describe the contents of a LuaRocks tree or server.
-- They are loaded into manifest tables, which are then used for
-- performing searches, matching dependencies, etc.
local manif = {}
package.loaded["luarocks.manif"] = manif

local manif_core = require("luarocks.manif_core")
local persist = require("luarocks.persist")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local search = require("luarocks.search")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local path = require("luarocks.path")
local repos = require("luarocks.repos")
local deps = require("luarocks.deps")

manif.rock_manifest_cache = {}

--- Commit a table to disk in given local path.
-- @param where string: The directory where the table should be saved.
-- @param name string: The filename.
-- @param tbl table: The table to be saved.
-- @return boolean or (nil, string): true if successful, or nil and a
-- message in case of errors.
local function save_table(where, name, tbl)
   assert(type(where) == "string")
   assert(type(name) == "string")
   assert(type(tbl) == "table")

   local filename = dir.path(where, name)
   local ok, err = persist.save_from_table(filename..".tmp", tbl)
   if ok then
      ok, err = fs.replace_file(filename, filename..".tmp")
   end
   return ok, err
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
   if not rock_manifest then return nil end
   manif.rock_manifest_cache[name_version] = rock_manifest
   return rock_manifest.rock_manifest
end

function manif.make_rock_manifest(name, version)
   local install_dir = path.install_dir(name, version)
   local tree = {}
   for _, file in ipairs(fs.find(install_dir)) do
      local full_path = dir.path(install_dir, file)
      local walk = tree
      local last
      local last_name
      for name in file:gmatch("[^/]+") do
         local next = walk[name]
         if not next then
            next = {}
            walk[name] = next
         end
         last = walk
         last_name = name
         walk = next
      end
      if fs.is_file(full_path) then
         local sum, err = fs.get_md5(full_path)
         if not sum then
            return nil, "Failed producing checksum: "..tostring(err)
         end
         last[last_name] = sum
      end
   end
   local rock_manifest = { rock_manifest=tree }
   manif.rock_manifest_cache[name.."/"..version] = rock_manifest
   save_table(install_dir, "rock_manifest", rock_manifest )
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

   local cached_manifest = manif_core.get_cached_manifest(repo_url, lua_version)
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
      local dir = dir.dir_name(pathname)
      fs.change_dir(dir)
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
   return manif_core.manifest_loader(pathname, repo_url, lua_version)
end

--- Update storage table to account for items provided by a package.
-- @param storage table: a table storing items in the following format:
-- keys are item names and values are arrays of packages providing each item,
-- where a package is specified as string `name/version`.
-- @param items table: a table mapping item names to paths.
-- @param name string: package name.
-- @param version string: package version.
local function store_package_items(storage, name, version, items)
   assert(type(storage) == "table")
   assert(type(items) == "table")
   assert(type(name) == "string")
   assert(type(version) == "string")

   local package_identifier = name.."/"..version

   for item_name, path in pairs(items) do
      if not storage[item_name] then
         storage[item_name] = {}
      end

      table.insert(storage[item_name], package_identifier)
   end
end

--- Update storage table removing items provided by a package.
-- @param storage table: a table storing items in the following format:
-- keys are item names and values are arrays of packages providing each item,
-- where a package is specified as string `name/version`.
-- @param items table: a table mapping item names to paths.
-- @param name string: package name.
-- @param version string: package version.
local function remove_package_items(storage, name, version, items)
   assert(type(storage) == "table")
   assert(type(items) == "table")
   assert(type(name) == "string")
   assert(type(version) == "string")

   local package_identifier = name.."/"..version

   for item_name, path in pairs(items) do
      local all_identifiers = storage[item_name]

      for i, identifier in ipairs(all_identifiers) do
         if identifier == package_identifier then
            table.remove(all_identifiers, i)
            break
         end
      end

      if #all_identifiers == 0 then
         storage[item_name] = nil
      end
   end
end

--- Sort function for ordering rock identifiers in a manifest's
-- modules table. Rocks are ordered alphabetically by name, and then
-- by version which greater first.
-- @param a string: Version to compare.
-- @param b string: Version to compare.
-- @return boolean: The comparison result, according to the
-- rule outlined above.
local function sort_pkgs(a, b)
   assert(type(a) == "string")
   assert(type(b) == "string")

   local na, va = a:match("(.*)/(.*)$")
   local nb, vb = b:match("(.*)/(.*)$")

   return (na == nb) and deps.compare_versions(va, vb) or na < nb
end

--- Sort items of a package matching table by version number (higher versions first).
-- @param tbl table: the package matching table: keys should be strings
-- and values arrays of strings with packages names in "name/version" format.
local function sort_package_matching_table(tbl)
   assert(type(tbl) == "table")

   if next(tbl) then
      for item, pkgs in pairs(tbl) do
         if #pkgs > 1 then
            table.sort(pkgs, sort_pkgs)
            -- Remove duplicates from the sorted array.
            local prev = nil
            local i = 1
            while pkgs[i] do
               local curr = pkgs[i]
               if curr == prev then
                  table.remove(pkgs, i)
               else
                  prev = curr
                  i = i + 1
               end
            end
         end
      end
   end
end

--- Process the dependencies of a manifest table to determine its dependency
-- chains for loading modules. The manifest dependencies information is filled
-- and any dependency inconsistencies or missing dependencies are reported to
-- standard error.
-- @param manifest table: a manifest table.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for no trees.
local function update_dependencies(manifest, deps_mode)
   assert(type(manifest) == "table")
   assert(type(deps_mode) == "string")
   
   for pkg, versions in pairs(manifest.repository) do
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            if repo.arch == "installed" then
               repo.dependencies = {}
               deps.scan_deps(repo.dependencies, manifest, pkg, version, deps_mode)
               repo.dependencies[pkg] = nil
            end
         end
      end
   end
end

--- Filter manifest table by Lua version, removing rockspecs whose Lua version
-- does not match.
-- @param manifest table: a manifest table.
-- @param lua_version string or nil: filter by Lua version
-- @param repodir string: directory of repository being scanned
-- @param cache table: temporary rockspec cache table
local function filter_by_lua_version(manifest, lua_version, repodir, cache)
   assert(type(manifest) == "table")
   assert(type(repodir) == "string")
   assert((not cache) or type(cache) == "table")
   
   cache = cache or {}
   lua_version = deps.parse_version(lua_version)
   for pkg, versions in pairs(manifest.repository) do
      local to_remove = {}
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            if repo.arch == "rockspec" then
               local pathname = dir.path(repodir, pkg.."-"..version..".rockspec")
               local rockspec, err = cache[pathname]
               if not rockspec then
                  rockspec, err = fetch.load_local_rockspec(pathname, true)
               end
               if rockspec then
                  cache[pathname] = rockspec
                  for _, dep in ipairs(rockspec.dependencies) do
                     if dep.name == "lua" then 
                        if not deps.match_constraints(lua_version, dep.constraints) then
                           table.insert(to_remove, version)
                        end
                        break
                     end
                  end
               else
                  util.printerr("Error loading rockspec for "..pkg.." "..version..": "..err)
               end
            end
         end
      end
      if next(to_remove) then
         for _, incompat in ipairs(to_remove) do
            versions[incompat] = nil
         end
         if not next(versions) then
            manifest.repository[pkg] = nil
         end
      end
   end
end

--- Store search results in a manifest table.
-- @param results table: The search results as returned by search.disk_search.
-- @param manifest table: A manifest table (must contain repository, modules, commands tables).
-- It will be altered to include the search results.
-- @return boolean or (nil, string): true in case of success, or nil followed by an error message.
local function store_results(results, manifest)
   assert(type(results) == "table")
   assert(type(manifest) == "table")

   for name, versions in pairs(results) do
      local pkgtable = manifest.repository[name] or {}
      for version, entries in pairs(versions) do
         local versiontable = {}
         for _, entry in ipairs(entries) do
            local entrytable = {}
            entrytable.arch = entry.arch
            if entry.arch == "installed" then
               local rock_manifest = manif.load_rock_manifest(name, version)
               if not rock_manifest then
                  return nil, "rock_manifest file not found for "..name.." "..version.." - not a LuaRocks 2 tree?"
               end

               entrytable.modules = repos.package_modules(name, version)
               store_package_items(manifest.modules, name, version, entrytable.modules)
               entrytable.commands = repos.package_commands(name, version)
               store_package_items(manifest.commands, name, version, entrytable.commands)
            end
            table.insert(versiontable, entrytable)
         end
         pkgtable[version] = versiontable
      end
      manifest.repository[name] = pkgtable
   end
   sort_package_matching_table(manifest.modules)
   sort_package_matching_table(manifest.commands)
   return true
end

--- Scan a LuaRocks repository and output a manifest file.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param repo A local repository directory.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for the default dependency mode from the configuration.
-- @param remote boolean: 'true' if making a manifest for a rocks server.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function manif.make_manifest(repo, deps_mode, remote)
   assert(type(repo) == "string")
   assert(type(deps_mode) == "string")

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   if not fs.is_dir(repo) then
      return nil, "Cannot access repository at "..repo
   end

   local query = search.make_query("")
   query.exact_name = false
   query.arch = "any"
   local results = search.disk_search(repo, query)
   local manifest = { repository = {}, modules = {}, commands = {} }

   manif_core.cache_manifest(repo, nil, manifest)

   local ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   if remote then
      local cache = {}
      for luaver in util.lua_versions() do
         local vmanifest = { repository = {}, modules = {}, commands = {} }
         local ok, err = store_results(results, vmanifest)
         filter_by_lua_version(vmanifest, luaver, repo, cache)
         save_table(repo, "manifest-"..luaver, vmanifest)
      end
   else
      update_dependencies(manifest, deps_mode)
   end

   return save_table(repo, "manifest", manifest)
end

--- Update manifest file for a local repository
-- adding information about a version of a package installed in that repository.
-- @param name string: Name of a package from the repository.
-- @param version string: Version of a package from the repository.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository is used.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for using the default dependency mode from the configuration.
-- @return boolean or (nil, string): True if manifest was updated successfully,
-- or nil and an error message.
function manif.add_to_manifest(name, version, repo, deps_mode)
   assert(type(name) == "string")
   assert(type(version) == "string")
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)
   assert(type(deps_mode) == "string")

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest, err = manif_core.load_local_manifest(rocks_dir)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")
      -- Manifest built by `manif.make_manifest` should already
      -- include information about given name and version,
      -- no need to update it.
      return manif.make_manifest(rocks_dir, deps_mode)
   end

   local results = {[name] = {[version] = {{arch = "installed", repo = rocks_dir}}}}

   local ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   update_dependencies(manifest, deps_mode)
   return save_table(rocks_dir, "manifest", manifest)
end

--- Update manifest file for a local repository
-- removing information about a version of a package.
-- @param name string: Name of a package removed from the repository.
-- @param version string: Version of a package removed from the repository.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository is used.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for using the default dependency mode from the configuration.
-- @return boolean or (nil, string): True if manifest was updated successfully,
-- or nil and an error message.
function manif.remove_from_manifest(name, version, repo, deps_mode)
   assert(type(name) == "string")
   assert(type(version) == "string")
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)
   assert(type(deps_mode) == "string")

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest, err = manif_core.load_local_manifest(rocks_dir)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")
      -- Manifest built by `manif.make_manifest` should already
      -- include up-to-date information, no need to update it.
      return manif.make_manifest(rocks_dir, deps_mode)
   end

   local package_entry = manifest.repository[name]

   local version_entry = package_entry[version][1]
   remove_package_items(manifest.modules, name, version, version_entry.modules)
   remove_package_items(manifest.commands, name, version, version_entry.commands)

   package_entry[version] = nil
   manifest.dependencies[name][version] = nil

   if not next(package_entry) then
      -- No more versions of this package.
      manifest.repository[name] = nil
      manifest.dependencies[name] = nil
   end

   update_dependencies(manifest, deps_mode)
   return save_table(rocks_dir, "manifest", manifest)
end

--- Report missing dependencies for all rocks installed in a repository.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository is used.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for using the default dependency mode from the configuration.
function manif.check_dependencies(repo, deps_mode)
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)
   assert(type(deps_mode) == "string")
   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest = manif_core.load_local_manifest(rocks_dir)
   if not manifest then
      return
   end

   for name, versions in util.sortedpairs(manifest.repository) do
      for version, version_entries in util.sortedpairs(versions, deps.compare_versions) do
         for _, entry in ipairs(version_entries) do
            if entry.arch == "installed" then
               if manifest.dependencies[name] and manifest.dependencies[name][version] then
                  deps.report_missing_dependencies(name, version, manifest.dependencies[name][version], deps_mode)
               end
            end
         end
      end
   end
end

function manif.zip_manifests()
   for ver in util.lua_versions() do
      local file = "manifest-"..ver
      local zip = file..".zip"
      fs.delete(dir.path(fs.current_dir(), zip))
      fs.zip(zip, file)
   end
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
   local manifest = manif_core.load_local_manifest(rocks_dir)
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
   local manifest = manif_core.load_local_manifest(rocks_dir)

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

return manif
