
--- Module for handling manifest files and tables.
-- Manifest files describe the contents of a LuaRocks tree or server.
-- They are loaded into manifest tables, which are then used for
-- performing searches, matching dependencies, etc.
module("luarocks.manif", package.seeall)

local manif_core = require("luarocks.manif_core")
local persist = require("luarocks.persist")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local search = require("luarocks.search")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local path = require("luarocks.path")
local rep = require("luarocks.rep")
local deps = require("luarocks.deps")

rock_manifest_cache = {}

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
   return persist.save_from_table(filename, tbl)
end

function load_rock_manifest(name, version, root)
   assert(type(name) == "string")
   assert(type(version) == "string")

   local name_version = name.."/"..version
   if rock_manifest_cache[name_version] then
      return rock_manifest_cache[name_version].rock_manifest
   end
   local pathname = path.rock_manifest_file(name, version, root)
   local rock_manifest = persist.load_into_table(pathname)
   if not rock_manifest then return nil end
   rock_manifest_cache[name_version] = rock_manifest
   return rock_manifest.rock_manifest
end

function make_rock_manifest(name, version)
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
         last[last_name] = fs.get_md5(full_path)
      end
   end
   local rock_manifest = { rock_manifest=tree }
   rock_manifest_cache[name.."/"..version] = rock_manifest
   save_table(install_dir, "rock_manifest", rock_manifest )
end

--- Load a local or remote manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_local_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string, [string]): A table representing the manifest,
-- or nil followed by an error message and an optional error code.
function load_manifest(repo_url)
   assert(type(repo_url) == "string")

   if manif_core.manifest_cache[repo_url] then
      return manif_core.manifest_cache[repo_url]
   end

   local protocol, pathname = dir.split_url(repo_url)
   if protocol == "file" then
      pathname = dir.path(pathname, "manifest")
   else
      local url = dir.path(repo_url, "manifest")
      local name = repo_url:gsub("[/:]","_")
      local file, err, errcode = fetch.fetch_url_at_temp_dir(url, "luarocks-manifest-"..name)
      if not file then
         return nil, "Failed fetching manifest for "..repo_url..(err and " - "..err or ""), errcode
      end
      pathname = file
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
local function update_dependencies(manifest)
   for pkg, versions in pairs(manifest.repository) do
      for version, repos in pairs(versions) do
         local current = pkg.." "..version
         for _, repo in ipairs(repos) do
            if repo.arch == "installed" then
               local missing
               repo.dependencies, missing = deps.scan_deps({}, {}, manifest, pkg, version)
               repo.dependencies[pkg] = nil
               if missing then
                  for miss, err in pairs(missing) do
                     if miss == current then
                        util.printerr("Tree inconsistency detected: "..current.." has no rockspec. "..err)
                     else
                        util.printerr("Missing dependency for "..pkg.." "..version..": "..miss)
                     end
                  end
               end
            end
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
               local rock_manifest = load_rock_manifest(name, version)
               if not rock_manifest then
                  return nil, "rock_manifest file not found for "..name.." "..version.." - not a LuaRocks 2 tree?"
               end
               entrytable.modules = store_package_items(rep.package_modules, name, version, manifest.modules)
               entrytable.commands = store_package_items(rep.package_commands, name, version, manifest.commands)
            end
            table.insert(versiontable, entrytable)
         end
         pkgtable[version] = versiontable
      end
      manifest.repository[name] = pkgtable
   end
   update_dependencies(manifest)
   sort_package_matching_table(manifest.modules)
   sort_package_matching_table(manifest.commands)
   return true
end

--- Scan a LuaRocks repository and output a manifest file.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param repo A local repository directory.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function make_manifest(repo)
   assert(type(repo) == "string")

   if not fs.is_dir(repo) then
      return nil, "Cannot access repository at "..repo
   end

   local query = search.make_query("")
   query.exact_name = false
   query.arch = "any"
   local results = search.disk_search(repo, query)
   local manifest = { repository = {}, modules = {}, commands = {} }
   manif_core.manifest_cache[repo] = manifest

   local ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   return save_table(repo, "manifest", manifest)
end

--- Load a manifest file from a local repository and add to the repository
-- information with regard to the given name and version.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param name string: Name of a package from the repository.
-- @param version string: Version of a package from the repository.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository configured as cfg.rocks_dir is used.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function update_manifest(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = path.rocks_dir(repo or cfg.root_dir)

   util.printout("Updating manifest for "..repo)

   local manifest, err = load_manifest(repo)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")
      local ok, err = make_manifest(repo)
      if not ok then
         return nil, err
      end
      manifest, err = load_manifest(repo)
      if not manifest then
         return nil, err
      end
   end

   local results = {[name] = {[version] = {{arch = "installed", repo = repo}}}}

   local ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   return save_table(repo, "manifest", manifest)
end

local function find_providers(file, root)
   assert(type(file) == "string")
   root = root or cfg.root_dir

   local manifest, err = manif_core.load_local_manifest(path.rocks_dir(root))
   if not manifest then
      return nil, err .. " -- corrupted local rocks tree?"
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
function find_current_provider(file, root)
   local providers, err = find_providers(file, root)
   if not providers then return nil, err end
   return providers[1]:match("([^/]*)/([^/]*)")
end

function find_next_provider(file, root)
   local providers, err = find_providers(file, root)
   if not providers then return nil, err end
   if providers[2] then
      return providers[2]:match("([^/]*)/([^/]*)")
   else
      return nil
   end
end
