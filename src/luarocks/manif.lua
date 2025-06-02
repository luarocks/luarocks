local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type



local manif = {}









local core = require("luarocks.core.manif")
local persist = require("luarocks.persist")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")
local path = require("luarocks.path")
local util = require("luarocks.util")
local queries = require("luarocks.queries")
local type_manifest = require("luarocks.type.manifest")






manif.cache_manifest = core.cache_manifest
manif.load_rocks_tree_manifests = core.load_rocks_tree_manifests
manif.scan_dependencies = core.scan_dependencies

manif.rock_manifest_cache = {}

local function check_manifest(repo_url, manifest, globals)
   local ok, err = type_manifest.check(manifest, globals)
   if not ok then
      core.cache_manifest(repo_url, cfg.lua_version, nil)
      return nil, "Error checking manifest: " .. err, "type"
   end
   return manifest
end

local postprocess_dependencies
do
   local postprocess_check = setmetatable({}, { __mode = "k" })
   postprocess_dependencies = function(manifest)
      if postprocess_check[manifest] then
         return
      end
      if manifest.dependencies then
         for _, versions in pairs(manifest.dependencies) do
            for _, entries in pairs(versions) do
               for k, v in ipairs(entries) do
                  entries[k] = queries.from_persisted_table(v)
               end
            end
         end
      end
      postprocess_check[manifest] = true
   end
end

function manif.load_rock_manifest(name, version, root)
   assert(not name:match("/"))

   local name_version = name .. "/" .. version
   if manif.rock_manifest_cache[name_version] then
      return manif.rock_manifest_cache[name_version].rock_manifest
   end
   local pathname = path.rock_manifest_file(name, version, root)
   local rock_manifest = persist.load_into_table(pathname)
   if not rock_manifest then
      return nil, "rock_manifest file not found for " .. name .. " " .. version .. " - not a LuaRocks tree?"
   end
   manif.rock_manifest_cache[name_version] = rock_manifest
   return rock_manifest.rock_manifest
end










function manif.load_manifest(repo_url, lua_version, versioned_only)
   lua_version = lua_version or cfg.lua_version

   local cached_manifest = core.get_cached_manifest(repo_url, lua_version)
   if cached_manifest then
      postprocess_dependencies(cached_manifest)
      return cached_manifest
   end

   local filenames = {
      "manifest-" .. lua_version .. ".zip",
      "manifest-" .. lua_version,
      not versioned_only and "manifest" or nil,
   }

   if util.get_luajit_version() then
      table.insert(filenames, 1, "manifest-" .. lua_version .. ".json")
   end

   local protocol, repodir = dir.split_url(repo_url)
   local pathname, from_cache
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
         pathname, err, errcode, from_cache = fetch.fetch_caching(dir.path(repo_url, filename), "no_mirror")
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
      local nozip = pathname:match("(.*)%.zip$")
      if not from_cache then
         local dirname = dir.dir_name(pathname)
         fs.change_dir(dirname)
         fs.delete(nozip)
         local ok, err = fs.unzip(pathname)
         fs.pop_dir()
         if not ok then
            fs.delete(pathname)
            fs.delete(pathname .. ".timestamp")
            return nil, "Failed extracting manifest file: " .. err
         end
      end
      pathname = nozip
   end
   local manifest, err, errcode = core.manifest_loader(pathname, repo_url, lua_version)
   if not manifest and type(err) == "string" then
      return nil, err, errcode
   end

   postprocess_dependencies(manifest)
   return check_manifest(repo_url, manifest, err)
end





function manif.get_provided_item(deploy_type, file_path)
   local item_type = deploy_type == "bin" and "command" or "module"
   local item_name = item_type == "command" and file_path or path.path_to_module(file_path)
   return item_type, item_name
end

local function get_providers(item_type, item_name, repo)
   local rocks_dir = path.rocks_dir(repo or cfg.root_dir)
   local manifest = manif.load_manifest(rocks_dir)
   return manifest and (manifest)[item_type .. "s"][item_name]
end








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









function manif.get_versions(dep, deps_mode)

   local name = dep.name
   local namespace = dep.namespace

   local version_set = {}
   path.map_trees(deps_mode, function(tree)
      local manifest = manif.load_manifest(path.rocks_dir(tree))

      if manifest and manifest.repository[name] then
         for version in pairs(manifest.repository[name]) do
            if dep.namespace then
               local ns_file = path.rock_namespace_file(name, version, tree)
               local fd = io.open(ns_file, "r")
               if fd then
                  local ns = fd:read("*a")
                  fd:close()
                  if ns == namespace then
                     version_set[version] = tree
                  end
               end
            else
               version_set[version] = tree
            end
         end
      end
   end)

   return util.keys(version_set), version_set
end

return manif
