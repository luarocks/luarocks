
--- A module which installs a Lua package loader that is LuaRocks-aware.
-- This loader uses dependency information from the LuaRocks tree to load
-- correct versions of modules. It does this by constructing a "context"
-- table in the environment, which records which versions of packages were
-- used to load previous modules, so that the loader chooses versions
-- that are declared to be compatible with the ones loaded earlier.
local global_env = _G
local package, require, ipairs, pairs, table, type, next, unpack =
      package, require, ipairs, pairs, table, type, next, unpack

module("luarocks.loader")

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
      local manifest, err = manif_core.load_local_manifest(path.rocks_dir(tree))
      if manifest then
         any_ok = true
         table.insert(trees, {tree=tree, manifest=manifest})
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
-- @param name string: The name of an installed rock.
-- @param version string: The version of the rock, in string format
function add_context(name, version)
   -- assert(type(name) == "string")
   -- assert(type(version) == "string")

   if context[name] then
      return
   end
   context[name] = version

   if not rocks_trees and not load_rocks_trees() then
      return nil
   end

   local providers = {}
   for _, tree in pairs(rocks_trees) do
      local manifest = tree.manifest

      local pkgdeps
      if manifest.dependencies and manifest.dependencies[name] then
         pkgdeps = manifest.dependencies[name][version]
      end
      if not pkgdeps then
         return nil
      end
      for _, dep in ipairs(pkgdeps) do
         local pkg, constraints = dep.name, dep.constraints
   
         for _, tree in pairs(rocks_trees) do
            local entries = tree.manifest.repository[pkg]
            if entries then
               for version, pkgs in pairs(entries) do
                  if (not constraints) or deps.match_constraints(deps.parse_version(version), constraints) then
                     add_context(pkg, version)
                  end
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

--- Request module to be loaded through other loaders,
-- once the proper name of the module has been determined.
-- For example, in case the module "socket.core" has been requested
-- to the LuaRocks loader and it determined based on context that
-- the version 2.0.2 needs to be loaded and it is not the current
-- version, the module requested for the other loaders will be
-- "socket.core_2_0_2".
-- @param module The module name requested by the user, such as "socket.core"
-- @param name The rock name, such as "luasocket"
-- @param version The rock version, such as "2.0.2-1"
-- @param module_name The actual module name, such as "socket.core" or "socket.core_2_0_2".
-- @return table or (nil, string): The module table as returned by some other loader,
-- or nil followed by an error message if no other loader managed to load the module.
local function call_other_loaders(module, name, version, module_name)
   for i, loader in pairs(package.loaders) do
      if loader ~= luarocks_loader then
         local results = { loader(module_name) }
         if type(results[1]) == "function" then
            return unpack(results)
         end
      end
   end
   return nil, "Failed loading module "..module.." in LuaRocks rock "..name.." "..version
end

--- Search for a module in the rocks trees
-- @param module string: module name (eg. "socket.core")
-- @param filter_module_name function(string, string, string, string, number):
-- a function that takes the module name (eg "socket.core"), the rock name
-- (eg "luasocket"), the version (eg "2.0.2-1"), the path of the rocks tree
-- (eg "/usr/local"), and the numeric index of the matching entry, so the
-- filter function can know if the matching module was the first entry or not.
-- @return string, string, string: name of the rock containing the module
-- (eg. "luasocket"), version of the rock (eg. "2.0.2-1"),
-- name of the module (eg. "socket.core", or "socket.core_2_0_2" if file is
-- stored versioned).
local function select_module(module, filter_module_name)
   --assert(type(module) == "string")
   --assert(type(filter_module_name) == "function")

   if not rocks_trees and not load_rocks_trees() then
      return nil
   end

   local providers = {}
   for _, tree in pairs(rocks_trees) do
      local entries = tree.manifest.modules[module]
      if entries then
         for i, entry in ipairs(entries) do
            local name, version = entry:match("^([^/]*)/(.*)$")
            local module_name = tree.manifest.repository[name][version][1].modules[module]
            if type(module_name) ~= "string" then
               error("Invalid format in manifest file (invalid data for "..tostring(name).." "..tostring(version)..")")
            end
            module_name = filter_module_name(module_name, name, version, tree.tree, i)
            if context[name] == version then
               return name, version, module_name
            end
            version = deps.parse_version(version)
            table.insert(providers, {name = name, version = version, module_name = module_name})
         end
      end
   end

   if next(providers) then
      table.sort(providers, sort_versions)
      local first = providers[1]
      return first.name, first.version.string, first.module_name
   end
end

--- Search for a module
-- @param module string: module name (eg. "socket.core")
-- @return string, string, string: name of the rock containing the module
-- (eg. "luasocket"), version of the rock (eg. "2.0.2-1"),
-- name of the module (eg. "socket.core", or "socket.core_2_0_2" if file is
-- stored versioned).
local function pick_module(module)
   return
      select_module(module, function(module_name, name, version, tree, i)
         if i > 1 then
            module_name = path.versioned_name(module_name, "", name, version)
         end
         module_name = path.path_to_module(module_name)
         return module_name
      end)
end

--- Return the pathname of the file that would be loaded for a module.
-- @param module string: module name (eg. "socket.core")
-- @return string, string, string: name of the rock containing the module
-- (eg. "luasocket"), version of the rock (eg. "2.0.2-1"),
-- filename of the module (eg. "/usr/local/lib/lua/5.1/socket/core.so")
function which(module)
   local name, version, module_name = 
      select_module(module, function(module_name, name, version, tree, i)
         local deploy_dir
         if module_name:match("%.lua$") then
            deploy_dir = path.deploy_lua_dir(tree)
            module_name = deploy_dir.."/"..module_name
         else
            deploy_dir = path.deploy_lib_dir(tree)
            module_name = deploy_dir.."/"..module_name
         end
         if i > 1 then
            module_name = path.versioned_name(module_name, deploy_dir, name, version)
         end
         return module_name
      end)
   return module_name
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
   local name, version, module_name = pick_module(module)
   if not name then
      return nil, "No LuaRocks module found for "..module
   else
      add_context(name, version)
      return call_other_loaders(module, name, version, module_name)
   end
end

table.insert(global_env.package.loaders, 1, luarocks_loader)
