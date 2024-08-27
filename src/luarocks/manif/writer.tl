
local record writer
end

local cfg = require("luarocks.core.cfg")
local search = require("luarocks.search")
local repos = require("luarocks.repos")
local deps = require("luarocks.deps")
local vers = require("luarocks.core.vers")
local fs = require("luarocks.fs")
local util = require("luarocks.util")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local path = require("luarocks.path")
local persist = require("luarocks.persist")
local manif = require("luarocks.manif")
local queries = require("luarocks.queries")

local type Manifest = require("luarocks.core.types.manifest").Manifest

local type Rockspec = require("luarocks.core.types.rockspec").Rockspec

local type Result = require("luarocks.core.types.result").Result

local type PersistableTable = require("luarocks.core.types.persist").PersistableTable

local type RockManifest = require("luarocks.core.types.rockmanifest").RockManifest
local type Entry = require("luarocks.core.types.rockmanifest").RockManifest.Entry

--- Update storage table to account for items provided by a package.
-- @param storage table: a table storing items in the following format:
-- keys are item names and values are arrays of packages providing each item,
-- where a package is specified as string `name/version`.
-- @param items table: a table mapping item names to paths.
-- @param name string: package name.
-- @param version string: package version.
local function store_package_items(storage: {string: {string}}, name: string, version: string, items: {string: string})
   assert(not name:match("/"))

   local package_identifier = name.."/"..version

   for item_name, _ in pairs(items) do  -- luacheck: ignore 431
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
local function remove_package_items(storage: {string: {string}}, name: string, version: string, items: {string: string})
   assert(not name:match("/"))

   local package_identifier = name.."/"..version

   for item_name, _path in pairs(items) do
      local key = item_name
      local all_identifiers = storage[key]
      if not all_identifiers then
         key = key .. ".init"
         all_identifiers = storage[key]
      end

      if all_identifiers then
         for i, identifier in ipairs(all_identifiers) do
            if identifier == package_identifier then
               table.remove(all_identifiers, i)
               break
            end
         end

         if #all_identifiers == 0 then
            storage[key] = nil
         end
      else
         util.warning("Cannot find entry for " .. item_name .. " in manifest -- corrupted manifest?")
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
local function update_dependencies(manifest: Manifest, deps_mode: string)

   if not manifest.dependencies then manifest.dependencies = {} end
   local mdeps = manifest.dependencies

   for pkg, versions in pairs(manifest.repository) do
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            if repo.arch == "installed" then
               local rd = {}
               repo.dependencies = rd
               deps.scan_deps(rd, mdeps, pkg, version, deps_mode)
               rd[pkg] = nil
            end
         end
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
local function sort_pkgs(a: string, b: string): boolean
   local na, va = a:match("(.*)/(.*)$")
   local nb, vb = b:match("(.*)/(.*)$")

   return (na == nb) and vers.compare_versions(va, vb) or na < nb
end

--- Sort items of a package matching table by version number (higher versions first).
-- @param tbl table: the package matching table: keys should be strings
-- and values arrays of strings with packages names in "name/version" format.
local function sort_package_matching_table(tbl: {string: {string}})

   if next(tbl) then
      for _item, pkgs in pairs(tbl) do
         if #pkgs > 1 then
            table.sort(pkgs, sort_pkgs)
            -- Remove duplicates from the sorted array.
            local prev: string = nil
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

--- Filter manifest table by Lua version, removing rockspecs whose Lua version
-- does not match.
-- @param manifest table: a manifest table.
-- @param lua_version string or nil: filter by Lua version
-- @param repodir string: directory of repository being scanned
-- @param cache table: temporary rockspec cache table
local function filter_by_lua_version(manifest: Manifest, lua_version_str: string, repodir: string, cache: {string: Rockspec})

   cache = cache or {}
   local lua_version = vers.parse_version(lua_version_str)
   for pkg, versions in pairs(manifest.repository) do
      local to_remove: {string} = {}
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            if repo.arch == "rockspec" then
               local pathname = dir.path(repodir, pkg.."-"..version..".rockspec")
               local rockspec = cache[pathname]
               local err: string
               if not rockspec then
                  rockspec, err = fetch.load_local_rockspec(pathname, true)
               end
               if rockspec then
                  cache[pathname] = rockspec
                  for _, dep in ipairs(rockspec.dependencies.queries) do
                     if dep.name == "lua" then
                        if not vers.match_constraints(lua_version, dep.constraints) then
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
local function store_results(results: {string: {string: {Result}}}, manifest: Manifest): boolean, string

   for name, versions in pairs(results) do
      local pkgtable = manifest.repository[name] or {}
      for version, entries in pairs(versions) do
         local versiontable = {}
         for _, entry in ipairs(entries) do
            local entrytable: Manifest.Entry = {}
            entrytable.arch = entry.arch
            if entry.arch == "installed" then
               local rock_manifest, err = manif.load_rock_manifest(name, version)
               if not rock_manifest then return nil, err end

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

--- Commit a table to disk in given local path.
-- @param where string: The directory where the table should be saved.
-- @param name string: The filename.
-- @param tbl table: The table to be saved.
-- @return boolean or (nil, string): true if successful, or nil and a
-- message in case of errors.
local function save_table(where: string, name: string, tbl: PersistableTable): boolean, string
   assert(not name:match("/"))

   local filename = dir.path(where, name)
   local ok, err = persist.save_from_table(filename..".tmp", tbl)
   if ok then
      ok, err = fs.replace_file(filename, filename..".tmp")
   end
   return ok, err
end

function writer.make_rock_manifest(name: string, version: string): boolean, string
   local install_dir = path.install_dir(name, version)
   local tree: {string: Entry} = {}
   for _, file in ipairs(fs.find(install_dir)) do
      local full_path = dir.path(install_dir, file)
      local walk = tree
      local last: {string : Entry}
      local last_name: string
      local nxt: Entry
      for filename in file:gmatch("[^\\/]+") do
         nxt = walk[filename]
         if not nxt then
            nxt = {}
            walk[filename] = nxt
         end
         last = walk
         last_name = filename
         assert(nxt is {string: Entry})
         walk = nxt
      end
      if fs.is_file(full_path) then

         local sum, err = fs.get_md5(full_path)
         if not sum then
            return nil, "Failed producing checksum: "..tostring(err)
         end
         last[last_name] = sum
      end
   end
   local rock_manifest: RockManifest = { rock_manifest=tree }
   manif.rock_manifest_cache[name.."/"..version] = rock_manifest
   save_table(install_dir, "rock_manifest", rock_manifest as PersistableTable)
   return true
end

-- Writes a 'rock_namespace' file in a locally installed rock directory.
-- @param name string: the rock name, without a namespace
-- @param version string: the rock version
-- @param namespace string?: the namespace
-- @return true if successful (or unnecessary, if there is no namespace),
-- or nil and an error message.
function writer.make_namespace_file(name: string, version: string, namespace?: string): boolean, string
   assert(not name:match("/"))
   if not namespace then
      return true
   end
   local fd, err = io.open(path.rock_namespace_file(name, version), "w")
   if not fd then
      return nil, err
   end
   fd, err = fd:write(namespace)
   if not fd then
      return nil, err
   end
   fd:close()
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
function writer.make_manifest(repo: string, deps_mode: string, remote?: boolean): boolean, string

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   if not fs.is_dir(repo) then
      return nil, "Cannot access repository at "..repo
   end

   local query = queries.all("any")
   local results = search.disk_search(repo, query)
   local manifest = { repository = {}, modules = {}, commands = {} }

   manif.cache_manifest(repo, nil, manifest)

   local ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   if remote then
      local cache = {}
      for luaver in util.lua_versions() do
         local vmanifest = { repository = {}, modules = {}, commands = {} }
         ok, err = store_results(results, vmanifest)
         filter_by_lua_version(vmanifest, luaver, repo, cache)
         if not cfg.no_manifest then
            save_table(repo, "manifest-"..luaver, vmanifest as PersistableTable)
         end
      end
   else
      update_dependencies(manifest, deps_mode)
   end

   if cfg.no_manifest then
      -- We want to have cache updated; but exit before save_table is called
      return true
   end
   return save_table(repo, "manifest", manifest as PersistableTable)
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
function writer.add_to_manifest(name: string, version: string, repo: string, deps_mode: string): boolean, string
   assert(not name:match("/"))
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest, err = manif.load_manifest(rocks_dir)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")
      -- Manifest built by `writer.make_manifest` should already
      -- include information about given name and version,
      -- no need to update it.
      return writer.make_manifest(rocks_dir, deps_mode)
   end

   local results: {string : {string : {Result}}} = {[name] = {[version] = {{arch = "installed", repo = rocks_dir}}}}

   local ok: boolean
   ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   update_dependencies(manifest, deps_mode)

   if cfg.no_manifest then
      return true
   end
   return save_table(rocks_dir, "manifest", manifest as PersistableTable)
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
function writer.remove_from_manifest(name: string, version: string, repo: string, deps_mode: string): boolean, string
   assert(not name:match("/"))
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest, _err = manif.load_manifest(rocks_dir)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")
      -- Manifest built by `writer.make_manifest` should already
      -- include up-to-date information, no need to update it.
      return writer.make_manifest(rocks_dir, deps_mode)
   end

   local package_entry = manifest.repository[name]
   if package_entry == nil or package_entry[version] == nil then
      -- entry is already missing from repository, no need to do anything
      return true
   end

   local version_entry = package_entry[version][1]
   if not version_entry then
      -- manifest looks corrupted, rebuild
      return writer.make_manifest(rocks_dir, deps_mode)
   end

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

   if cfg.no_manifest then
      return true
   end
   return save_table(rocks_dir, "manifest", manifest as PersistableTable)
end

return writer
