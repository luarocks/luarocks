local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type
local writer = {}


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



















local function store_package_items(storage, name, version, items)
   assert(not name:match("/"))

   local package_identifier = name .. "/" .. version

   for item_name, _ in pairs(items) do
      if not storage[item_name] then
         storage[item_name] = {}
      end

      table.insert(storage[item_name], package_identifier)
   end
end








local function remove_package_items(storage, name, version, items)
   assert(not name:match("/"))

   local package_identifier = name .. "/" .. version

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









local function update_dependencies(manifest, deps_mode)

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










local function sort_pkgs(a, b)
   local na, va = a:match("(.*)/(.*)$")
   local nb, vb = b:match("(.*)/(.*)$")

   return (na == nb) and vers.compare_versions(va, vb) or na < nb
end




local function sort_package_matching_table(tbl)

   if next(tbl) then
      for _item, pkgs in pairs(tbl) do
         if #pkgs > 1 then
            table.sort(pkgs, sort_pkgs)

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







local function filter_by_lua_version(manifest, lua_version_str, repodir, cache)

   cache = cache or {}
   local lua_version = vers.parse_version(lua_version_str)
   for pkg, versions in pairs(manifest.repository) do
      local to_remove = {}
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            if repo.arch == "rockspec" then
               local pathname = dir.path(repodir, pkg .. "-" .. version .. ".rockspec")
               local rockspec = cache[pathname]
               local err
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
                  util.printerr("Error loading rockspec for " .. pkg .. " " .. version .. ": " .. err)
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






local function store_results(results, manifest)

   for name, versions in pairs(results) do
      local pkgtable = manifest.repository[name] or {}
      for version, entries in pairs(versions) do
         local versiontable = {}
         for _, entry in ipairs(entries) do
            local entrytable = {}
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







local function save_table(where, name, tbl)
   assert(not name:match("/"))

   local filename = dir.path(where, name)
   local ok, err = persist.save_from_table(filename .. ".tmp", tbl)
   if ok then
      ok, err = fs.replace_file(filename, filename .. ".tmp")
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
      local nxt
      for filename in file:gmatch("[^\\/]+") do
         nxt = walk[filename]
         if not nxt then
            nxt = {}
            walk[filename] = nxt
         end
         last = walk
         last_name = filename
         assert(type(nxt) == "table")
         walk = nxt
      end
      if fs.is_file(full_path) then

         local sum, err = fs.get_md5(full_path)
         if not sum then
            return nil, "Failed producing checksum: " .. tostring(err)
         end
         last[last_name] = sum
      end
   end
   local rock_manifest = { rock_manifest = tree }
   manif.rock_manifest_cache[name .. "/" .. version] = rock_manifest
   save_table(install_dir, "rock_manifest", rock_manifest)
   return true
end







function writer.make_namespace_file(name, version, namespace)
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











function writer.make_manifest(repo, deps_mode, remote)

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   if not fs.is_dir(repo) then
      return nil, "Cannot access repository at " .. repo
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
            save_table(repo, "manifest-" .. luaver, vmanifest)
         end
      end
   else
      update_dependencies(manifest, deps_mode)
   end

   if cfg.no_manifest then

      return true
   end
   return save_table(repo, "manifest", manifest)
end












function writer.add_to_manifest(name, version, repo, deps_mode)
   assert(not name:match("/"))
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest, err = manif.load_manifest(rocks_dir)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")



      return writer.make_manifest(rocks_dir, deps_mode)
   end

   local results = { [name] = { [version] = { { arch = "installed", repo = rocks_dir } } } }

   local ok
   ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   update_dependencies(manifest, deps_mode)

   if cfg.no_manifest then
      return true
   end
   return save_table(rocks_dir, "manifest", manifest)
end












function writer.remove_from_manifest(name, version, repo, deps_mode)
   assert(not name:match("/"))
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)

   if deps_mode == "none" then deps_mode = cfg.deps_mode end

   local manifest, _err = manif.load_manifest(rocks_dir)
   if not manifest then
      util.printerr("No existing manifest. Attempting to rebuild...")


      return writer.make_manifest(rocks_dir, deps_mode)
   end

   local package_entry = manifest.repository[name]
   if package_entry == nil or package_entry[version] == nil then

      return true
   end

   local version_entry = package_entry[version][1]
   if not version_entry then

      return writer.make_manifest(rocks_dir, deps_mode)
   end

   remove_package_items(manifest.modules, name, version, version_entry.modules)
   remove_package_items(manifest.commands, name, version, version_entry.commands)

   package_entry[version] = nil
   manifest.dependencies[name][version] = nil

   if not next(package_entry) then

      manifest.repository[name] = nil
      manifest.dependencies[name] = nil
   end

   update_dependencies(manifest, deps_mode)

   if cfg.no_manifest then
      return true
   end
   return save_table(rocks_dir, "manifest", manifest)
end

return writer
