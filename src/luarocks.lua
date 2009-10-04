--- Install a custom LuaRocks loader.
-- TODO use new tree format.

local global_env = _G
local plain_package_path = package.path
local plain_package_cpath = package.cpath
local package, require, assert, ipairs, pairs, os, print, table, type, next, unpack =
      package, require, assert, ipairs, pairs, os, print, table, type, next, unpack

module("luarocks")

local path = require("luarocks.path")
local manif_core = require("luarocks.manif_core")
local deps = require("luarocks.deps")
local cfg = require("luarocks.cfg")

context = {}

-- Contains a table when rocks trees are loaded,
-- or 'false' to indicate rocks trees failed to load.
-- 'nil' indicates rocks trees were not attempted to be loaded yet.
rocks_trees = nil

local function load_rocks_trees() 
   local any_ok = false
   local trees = {}
   for _, tree in pairs(cfg.rocks_trees) do
      local rocks_dir = path.rocks_dir(tree)
      local manifest, err = manif_core.load_local_manifest(rocks_dir)
      if manifest then
         any_ok = true
         table.insert(trees, {rocks_dir=rocks_dir, manifest=manifest})
      end
   end
   if not any_ok then
      rocks_trees = false
      return false
   end
   rocks_trees = trees
   return true
end

--- Process the dependencies of a package to determine its dependency
-- chain for loading modules.
-- @parse name string: The name of an installed rock.
-- @parse version string: The version of the rock, in string format
-- @parse manifest table: The local manifest table where this rock
-- is installed.
local function add_context(name, version, manifest)
   -- assert(type(name) == "string")
   -- assert(type(version) == "string")
   -- assert(type(manifest) == "table")

   if context[name] then
      return
   end
   context[name] = version

   local pkgdeps = manifest.dependencies and manifest.dependencies[name][version]
   if not pkgdeps then
      return
   end
   for _, dep in ipairs(pkgdeps) do
      local package, constraints = dep.name, dep.constraints

      for _, tree in pairs(rocks_trees) do
         local entries = tree.manifest.repository[package]
         if entries then
            for version, packages in pairs(entries) do
               if (not constraints) or deps.match_constraints(deps.parse_version(version), constraints) then
                  add_context(package, version, tree.manifest)
               end
            end
         end
      end
   end
end

--- Internal sorting function.
-- @param a table: A provider table.
-- @param b table: Another provider table.
-- @return boolean: True if the version of a is greater than that of b.
local function sort_versions(a,b)
   return a.version > b.version
end

--- Specify a dependency chain for LuaRocks.
-- In the presence of multiple versions of packages, it is necessary to,
-- at some point, indicate which dependency chain we're following.
-- set_context does this by allowing one to pick a package to be the
-- root of this dependency chain. Once a dependency chain is picked it's
-- easy to know which modules to load ("I want to use *this* version of
-- A, which requires *that* version of B, which requires etc etc etc").
-- @param name string: The package name of an installed rock.
-- @param version string or nil: Optionally, a version number
-- When a version is not given, it picks the highest version installed.
-- @return boolean: true if succeeded, false otherwise.
function set_context(name, version)
   --assert(type(name) == "string")
   --assert(type(version) == "string" or not version)

   if rocks_trees == false or (not rocks_trees and not load_rocks_trees()) then
      return false
   end

   local manifest
   local vtables = {}
   for _, tree in ipairs(rocks_trees) do
      if version then
         local manif_repo = tree.manifest.repository
         if manif_repo[name] and manif_repo[name][version] then
            manifest = tree.manifest
            break
         end
      else
         local versions = manif_core.get_versions(name, tree.manifest)
         for _, version in ipairs(versions) do
            table.insert(vtables, {version = deps.parse_version(version), manifest = tree.manifest})
         end
      end
   end
   if not version then
      if not next(vtables) then
         table.sort(vtables, sort_versions)
         local highest = vtables[#vtables]
         version = highest.version.string
         manifest = highest.manifest
      end
   end
   if not manifest then
      return false
   end

   add_context(name, version, manifest)
   -- TODO: platform independence
   local lpath, cpath = "", ""
   for name, version in pairs(context) do
      lpath = lpath .. path.lua_dir(name, version) .. "/?.lua;"
      lpath = lpath .. path.lua_dir(name, version) .. "/?/init.lua;"
      cpath = cpath .. path.lib_dir(name, version) .."/?."..cfg.lib_extension..";"
   end
   global_env.package.path = lpath .. plain_package_path
   global_env.package.cpath = cpath .. plain_package_cpath
end

local function call_other_loaders(module, name, version, rocks_dir)
   local save_path = package.path
   local save_cpath = package.cpath
   package.path = path.lua_dir(name, version, rocks_dir) .. "/?.lua;"
               .. path.lua_dir(name, version, rocks_dir) .. "/?/init.lua;" .. save_path
   package.cpath = path.lib_dir(name, version, rocks_dir) .. "/?."..cfg.lib_extension..";" .. save_cpath
   for i, loader in pairs(package.loaders) do
      if loader ~= luarocks_loader then
         local results = { loader(module) }
         if type(results[1]) == "function" then
            package.path = save_path
            package.cpath = save_cpath
            return unpack(results)
         end
      end
   end
   package.path = save_path
   package.cpath = save_cpath
   return nil, "Failed loading module "..module.." in LuaRocks rock "..name.." "..version
end

local function pick_module(module, constraints)
   --assert(type(module) == "string")
   --assert(not constraints or type(constraints) == "string")

   if not rocks_trees and not load_rocks_trees() then
      return nil
   end

   if constraints then
      if type(constraints) == "string" then
         constraints = deps.parse_constraints(constraints)
      else
         constraints = nil
      end
   end

   local providers = {}
   for _, tree in pairs(rocks_trees) do
      local entries = tree.manifest.modules[module]
      if entries then
         for entry, _ in pairs(entries) do
            local name, version = entry:match("^([^/]*)/(.*)$")
            if context[name] == version then
               return name, version, tree
            end
            version = deps.parse_version(version)
            if (not constraints) or deps.match_constraints(version, constraints) then
               table.insert(providers, {name = name, version = version, repo = tree})
            end
         end
      end
   end

   if next(providers) then
      table.sort(providers, sort_versions)
      local first = providers[1]
      return first.name, first.version.string, first.repo
   end
end

--- Inform which rock LuaRocks would use if require() is called
-- with the given arguments.
-- @param module string: The module name, like in plain require().
-- @param constraints string or nil: An optional comma-separated
-- list of version constraints.
-- @return (string, string) or nil: Rock name and version if the
-- requested module can be supplied by LuaRocks, or nil if it can't.
function get_rock_from_module(module, constraints) 
   --assert(type(module) == "string")
   --assert(not constraints or type(constraints) == "string")
   local name, version = pick_module(module, constraints)
   return name, version
end

--- Package loader for LuaRocks support.
-- A module is searched in installed rocks that match the
-- current LuaRocks context. If module is not part of the
-- context, or if a context has not yet been set, the module
-- in the package with the highest version is used.
-- @param module string: The module name, like in plain require().
-- @return table: The module table (typically), like in plain
-- require(). See <a href="http://www.lua.org/manual/5.1/manual.html#pdf-require">require()</a>
-- in the Lua reference manual for details.

function luarocks_loader(module)
   local name, version, repo = pick_module(module)
   if not name then
      return nil, "No LuaRocks module found for "..module
   else
      add_context(name, version, repo.manifest)
      return call_other_loaders(module, name, version, repo.rocks_dir)
   end
end

table.insert(global_env.package.loaders, luarocks_loader)
