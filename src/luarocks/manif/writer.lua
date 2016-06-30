
local writer = {}

local cfg = require("luarocks.core.cfg")
local search = require("luarocks.search")
local repos = require("luarocks.repos")
local deps = require("luarocks.deps")
local fs = require("luarocks.fs")
local util = require("luarocks.util")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local path = require("luarocks.path")
local persist = require("luarocks.persist")
local manif = require("luarocks.manif")

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

function writer.make_rock_manifest(name, version)
   local install_dir = path.install_dir(name, version)
   local tree = {}
   for _, file in ipairs(fs.find(install_dir)) do
      local full_path = dir.path(install_dir, file)
      local walk = tree
      local last
      local last_name
      for filename in file:gmatch("[^/]+") do
         local next = walk[filename]
         if not next then
            next = {}
            walk[filename] = next
         end
         last = walk
         last_name = filename
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
function writer.make_manifest(repo, deps_mode, remote)
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

   manif.cache_manifest(repo, nil, manifest)

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
         store_results(results, vmanifest, dep_handler)
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
function writer.update_manifest(name, version, repo, deps_mode)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = path.rocks_dir(repo or cfg.root_dir)
   assert(type(deps_mode) == "string")
   
   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest, err = manif.load_manifest(repo)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")
      local ok, err = writer.make_manifest(repo, deps_mode)
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

return writer
