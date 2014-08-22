--- Module for handling manifest files and tables.
-- Manifest files describe the contents of a LuaRocks tree or server.
-- They are loaded into manifest tables, which are then used for
-- performing searches, matching dependencies, etc.
--module("luarocks.manif", package.seeall)
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
   local rock_manifest = path.rock_manifest_file(name, version)
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
   rock_manifest = { rock_manifest=tree }
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
-- @return table or (nil, string, [string]): A table representing the manifest,
-- or nil followed by an error message and an optional error code.
function manif.load_manifest(repo_url)
   assert(type(repo_url) == "string")

   if manif_core.manifest_cache[repo_url] then
      return manif_core.manifest_cache[repo_url]
   end
   
   local filenames = {
      "manifest-"..cfg.lua_version..".zip",
      "manifest-"..cfg.lua_version,
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
   return manif_core.manifest_loader(pathname, repo_url)
end

--- Output a table listing items of a package.
-- @param itemsfn function: a function for obtaining items of a package.
-- pkg and version will be passed to it; it should return a table with
-- items as keys.
-- @param pkg string: package name
-- @param version string: package version
-- @param tbl table: the package matching table: keys should be item names
-- and values arrays of strings with packages names in "name/version" format.
local function store_package_items(itemsfn, pkg, version, tbl)
   assert(type(itemsfn) == "function")
   assert(type(pkg) == "string")
   assert(type(version) == "string")
   assert(type(tbl) == "table")

   local pkg_version = pkg.."/"..version
   local result = {}

   for item, path in pairs(itemsfn(pkg, version)) do
      result[item] = path
      if not tbl[item] then
         tbl[item] = {}
      end
      table.insert(tbl[item], pkg_version)
   end
   return result
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
         local current = pkg.." "..version
         for _, repo in ipairs(repositories) do
            if repo.arch == "installed" then
               local missing
               repo.dependencies, missing = deps.scan_deps({}, {}, manifest, pkg, version, deps_mode)
               repo.dependencies[pkg] = nil
               if missing then
                  for miss, err in pairs(missing) do
                     if miss == current then
                        util.printerr("Tree inconsistency detected: "..current.." has no rockspec. "..err)
                     elseif deps_mode ~= "none" then
                        util.printerr("Missing dependency for "..pkg.." "..version..": "..miss)
                     end
                  end
               end
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
-- @param dep_handler: dependency handler function
-- @return boolean or (nil, string): true in case of success, or nil followed by an error message.
local function store_results(results, manifest, dep_handler)
   assert(type(results) == "table")
   assert(type(manifest) == "table")
   assert((not dep_handler) or type(dep_handler) == "function")

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
               entrytable.modules = store_package_items(repos.package_modules, name, version, manifest.modules)
               entrytable.commands = store_package_items(repos.package_commands, name, version, manifest.commands)
            end
            table.insert(versiontable, entrytable)
         end
         pkgtable[version] = versiontable
      end
      manifest.repository[name] = pkgtable
   end
   if dep_handler then
      dep_handler(manifest)
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
-- @param versioned boolean: if versioned versions of the manifest should be created.
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

   manif_core.manifest_cache[repo] = manifest

   local dep_handler = nil
   if not remote then
      dep_handler = function(manifest)
         update_dependencies(manifest, deps_mode)
      end
   end
   local ok, err = store_results(results, manifest, dep_handler)
   if not ok then return nil, err end

   if remote then
      local cache = {}
      for luaver in util.lua_versions() do
         local vmanifest = { repository = {}, modules = {}, commands = {} }
         local dep_handler = function(manifest)
            filter_by_lua_version(manifest, luaver, repo, cache)
         end
         local ok, err = store_results(results, vmanifest, dep_handler)
         save_table(repo, "manifest-"..luaver, vmanifest)
      end
   end

   return save_table(repo, "manifest", manifest)
end

--- Load a manifest file from a local repository and add to the repository
-- information with regard to the given name and version.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param name string: Name of a package from the repository.
-- @param version string: Version of a package from the repository.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository is used.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for using the default dependency mode from the configuration.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function manif.update_manifest(name, version, repo, deps_mode)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = path.rocks_dir(repo or cfg.root_dir)
   assert(type(deps_mode) == "string")
   
   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   util.printout("Updating manifest for "..repo)

   local manifest, err = manif.load_manifest(repo)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")
      local ok, err = manif.make_manifest(repo, deps_mode)
      if not ok then
         return nil, err
      end
      manifest, err = manif.load_manifest(repo)
      if not manifest then
         return nil, err
      end
   end

   local results = {[name] = {[version] = {{arch = "installed", repo = repo}}}}

   local dep_handler = function(manifest)
      update_dependencies(manifest, deps_mode)
   end
   local ok, err = store_results(results, manifest, dep_handler)
   if not ok then return nil, err end

   return save_table(repo, "manifest", manifest)
end

function manif.zip_manifests()
   for ver in util.lua_versions() do
      local file = "manifest-"..ver
      local zip = file..".zip"
      fs.delete(dir.path(fs.current_dir(), zip))
      fs.zip(zip, file)
   end
end

local function find_providers(file, root)
   assert(type(file) == "string")
   root = root or cfg.root_dir

   local manifest, err = manif_core.load_local_manifest(path.rocks_dir(root))
   if not manifest then
      return nil, "untracked"
   end
   local deploy_bin = path.deploy_bin_dir(root)
   local deploy_lua = path.deploy_lua_dir(root)
   local deploy_lib = path.deploy_lib_dir(root)
   local key, manifest_tbl

   if util.starts_with(file, deploy_lua) then
      manifest_tbl = manifest.modules
      key = path.path_to_module(file:sub(#deploy_lua+1):gsub("\\", "/"))
   elseif util.starts_with(file, deploy_lib) then
      manifest_tbl = manifest.modules
      key = path.path_to_module(file:sub(#deploy_lib+1):gsub("\\", "/"))
   elseif util.starts_with(file, deploy_bin) then
      manifest_tbl = manifest.commands
      key = file:sub(#deploy_bin+1):gsub("^[\\/]*", "")
   else
      assert(false, "Assertion failed: '"..file.."' is not a deployed file.")
   end

   local providers = manifest_tbl[key]
   if not providers then
      return nil, "untracked"
   end
   return providers
end

--- Given a path of a deployed file, figure out which rock name and version
-- correspond to it in the tree manifest.
-- @param file string: The full path of a deployed file.
-- @param root string or nil: A local root dir for a rocks tree. If not given, the default is used.
-- @return string, string: name and version of the provider rock.
function manif.find_current_provider(file, root)
   local providers, err = find_providers(file, root)
   if not providers then return nil, err end
   return providers[1]:match("([^/]*)/([^/]*)")
end

function manif.find_next_provider(file, root)
   local providers, err = find_providers(file, root)
   if not providers then return nil, err end
   if providers[2] then
      return providers[2]:match("([^/]*)/([^/]*)")
   else
      return nil
   end
end

return manif
