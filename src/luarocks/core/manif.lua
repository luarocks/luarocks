local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type

local manif = {}


local persist = require("luarocks.core.persist")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.core.dir")
local util = require("luarocks.core.util")
local vers = require("luarocks.core.vers")
local path = require("luarocks.core.path")














local manifest_cache = {}





function manif.cache_manifest(repo_url, lua_version, manifest)
   lua_version = lua_version or cfg.lua_version
   manifest_cache[repo_url] = manifest_cache[repo_url] or {}
   manifest_cache[repo_url][lua_version] = manifest
end





function manif.get_cached_manifest(repo_url, lua_version)
   lua_version = lua_version or cfg.lua_version
   return manifest_cache[repo_url] and manifest_cache[repo_url][lua_version]
end








function manif.manifest_loader(file, repo_url, lua_version)
   local manifest, err, errcode

   if file:match(".*%.json$") then
      manifest, err, errcode = persist.load_json_into_table(file)
   else
      manifest, err, errcode = persist.load_into_table(file)
   end

   if not manifest and type(err) == "string" then
      return nil, "Failed loading manifest for " .. repo_url .. ": " .. err, errcode
   end

   manif.cache_manifest(repo_url, lua_version, manifest)
   return manifest, err, errcode
end






function manif.fast_load_local_manifest(repo_url)

   local cached_manifest = manif.get_cached_manifest(repo_url)
   if cached_manifest then
      return cached_manifest
   end

   local pathname = dir.path(repo_url, "manifest")
   return manif.manifest_loader(pathname, repo_url, nil)
end

function manif.load_rocks_tree_manifests(deps_mode)
   local trees = {}
   path.map_trees(deps_mode, function(tree)
      local manifest = manif.fast_load_local_manifest(path.rocks_dir(tree))
      if manifest then
         table.insert(trees, { tree = tree, manifest = manifest })
      end
   end)
   return trees
end

function manif.scan_dependencies(name, version, tree_manifests, dest)
   if dest[name] then
      return
   end
   dest[name] = version

   for _, tree in ipairs(tree_manifests) do
      local manifest = tree.manifest

      local pkgdeps
      if manifest.dependencies and manifest.dependencies[name] then
         pkgdeps = manifest.dependencies[name][version]
      end
      if pkgdeps then
         for _, dep in ipairs(pkgdeps) do
            local pkg, constraints = dep.name, dep.constraints

            for _, t in ipairs(tree_manifests) do
               local entries = t.manifest.repository[pkg]
               if entries then
                  for ver, _ in util.sortedpairs(entries, vers.compare_versions) do
                     if (not constraints) or vers.match_constraints(vers.parse_version(ver), constraints) then
                        manif.scan_dependencies(pkg, ver, tree_manifests, dest)
                     end
                  end
               end
            end
         end
         return
      end
   end
end

return manif
