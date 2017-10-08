
--- High-level dependency related functions.
local deps = {}

local cfg = require("luarocks.core.cfg")
local manif = require("luarocks.manif")
local path = require("luarocks.path")
local util = require("luarocks.util")
local vers = require("luarocks.vers")

--- Attempt to match a dependency to an installed rock.
-- @param dep table: A dependency parsed in table format.
-- @param blacklist table: Versions that can't be accepted. Table where keys
-- are program versions and values are 'true'.
-- @param rocks_provided table: A table of auto-dependencies provided 
-- by this Lua implementation for the given dependency.
-- @return string or nil: latest installed version of the rock matching the dependency
-- or nil if it could not be matched.
local function match_dep(dep, blacklist, deps_mode, rocks_provided)
   assert(type(dep) == "table")
   assert(type(rocks_provided) == "table")
  
   local versions
   local provided = rocks_provided[dep.name]
   if provided then
      -- Provided rocks have higher priority than manifest's rocks.
      versions = { provided }
   else
      versions = manif.get_versions(dep.name, deps_mode)
   end

   local latest_version
   for _, vstring in ipairs(versions) do
      if not blacklist or not blacklist[vstring] then
         local version = vers.parse_version(vstring)
         if vers.match_constraints(version, dep.constraints) then
            if not latest_version or version > latest_version then
               latest_version = version
            end
         end
      end
   end

   return latest_version and latest_version.string
end

--- Attempt to match dependencies of a rockspec to installed rocks.
-- @param rockspec table: The rockspec loaded as a table.
-- @param blacklist table or nil: Program versions to not use as valid matches.
-- Table where keys are program names and values are tables where keys
-- are program versions and values are 'true'.
-- @return table, table, table: A table where keys are dependencies parsed
-- in table format and values are tables containing fields 'name' and
-- version' representing matches; a table of missing dependencies
-- parsed as tables; and a table of "no-upgrade" missing dependencies
-- (to be used in plugin modules so that a plugin does not force upgrade of
-- its parent application).
function deps.match_deps(rockspec, blacklist, deps_mode)
   assert(type(rockspec) == "table")
   assert(type(blacklist) == "table" or not blacklist)
   local matched, missing, no_upgrade = {}, {}, {}
   
   for _, dep in ipairs(rockspec.dependencies) do
      local found = match_dep(dep, blacklist and blacklist[dep.name] or nil, deps_mode, rockspec.rocks_provided)
      if found then
         if not rockspec.rocks_provided[dep.name] then
            matched[dep] = {name = dep.name, version = found}
         end
      else
         if dep.constraints[1] and dep.constraints[1].no_upgrade then
            no_upgrade[dep.name] = dep
         else
            missing[dep.name] = dep
         end
      end
   end
   return matched, missing, no_upgrade
end

--- Return a set of values of a table.
-- @param tbl table: The input table.
-- @return table: The array of keys.
local function values_set(tbl)
   local set = {}
   for _, v in pairs(tbl) do
      set[v] = true
   end
   return set
end

local function rock_status(name, deps_mode, rocks_provided)
   local search = require("luarocks.search")
   local installed = match_dep(search.make_query(name), nil, deps_mode, rocks_provided)
   local installation_type = rocks_provided[name] and "provided by VM" or "installed"
   return installed and installed.." "..installation_type or "not installed"
end

--- Check depenendencies of a package and report any missing ones.
-- @param name string: package name.
-- @param version string: package version.
-- @param dependencies table: array of dependencies.
-- @param deps_mode string: Which trees to check dependencies for:
-- @param rocks_provided table: A table of auto-dependencies provided 
-- by this Lua implementation for the given dependency.
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
function deps.report_missing_dependencies(name, version, dependencies, deps_mode, rocks_provided)
   local first_missing_dep = true

   for _, dep in ipairs(dependencies) do
      if not match_dep(dep, nil, deps_mode, rocks_provided) then
         if first_missing_dep then
            util.printout(("Missing dependencies for %s %s:"):format(name, version))
            first_missing_dep = false
         end

         util.printout(("   %s (%s)"):format(vers.show_dep(dep), rock_status(dep.name, deps_mode, rocks_provided)))
      end
   end
end

--- Check dependencies of a rock and attempt to install any missing ones.
-- Packages are installed using the LuaRocks "install" command.
-- Aborts the program if a dependency could not be fulfilled.
-- @param rockspec table: A rockspec in table format.
-- @return boolean or (nil, string, [string]): True if no errors occurred, or
-- nil and an error message if any test failed, followed by an optional
-- error code.
function deps.fulfill_dependencies(rockspec, deps_mode)

   local search = require("luarocks.search")
   local install = require("luarocks.cmd.install")

   if rockspec.supported_platforms then
      if not deps.platforms_set then
         deps.platforms_set = values_set(cfg.platforms)
      end
      local supported = nil
      for _, plat in pairs(rockspec.supported_platforms) do
         local neg
         neg, plat = plat:match("^(!?)(.*)")
         if neg == "!" then
            if deps.platforms_set[plat] then
               return nil, "This rockspec for "..rockspec.package.." does not support "..plat.." platforms."
            end
         else
            if deps.platforms_set[plat] then
               supported = true
            else
               if supported == nil then
                  supported = false
               end
            end
         end
      end
      if supported == false then
         local plats = table.concat(cfg.platforms, ", ")
         return nil, "This rockspec for "..rockspec.package.." does not support "..plats.." platforms."
      end
   end

   deps.report_missing_dependencies(rockspec.name, rockspec.version, rockspec.dependencies, deps_mode, rockspec.rocks_provided)

   local first_missing_dep = true

   for _, dep in ipairs(rockspec.dependencies) do
      if not match_dep(dep, nil, deps_mode, rockspec.rocks_provided) then
         if first_missing_dep then
            util.printout()
            first_missing_dep = false
         end

         util.printout(("%s %s depends on %s (%s)"):format(
            rockspec.name, rockspec.version, vers.show_dep(dep), rock_status(dep.name, deps_mode, rockspec.rocks_provided)))

         if dep.constraints[1] and dep.constraints[1].no_upgrade then
            util.printerr("This version of "..rockspec.name.." is designed for use with")
            util.printerr(vers.show_dep(dep)..", but is configured to avoid upgrading it")
            util.printerr("automatically. Please upgrade "..dep.name.." with")
            util.printerr("   luarocks install "..dep.name)
            util.printerr("or choose an older version of "..rockspec.name.." with")
            util.printerr("   luarocks search "..rockspec.name)
            return nil, "Failed matching dependencies"
         end

         local url, search_err = search.find_suitable_rock(dep)
         if not url then
            return nil, "Could not satisfy dependency "..vers.show_dep(dep)..": "..search_err
         end
         util.printout("Installing "..url)
         local ok, install_err, errcode = install.command({deps_mode = deps_mode}, url)
         if not ok then
            return nil, "Failed installing dependency: "..url.." - "..install_err, errcode
         end
      end
   end

   return true
end

--- Recursively add satisfied dependencies of a package to a table,
-- to build a transitive closure of all dependent packages.
-- Additionally ensures that `dependencies` table of the manifest is up-to-date.
-- @param results table: The results table being built, maps package names to versions.
-- @param manifest table: The manifest table containing dependencies.
-- @param name string: Package name.
-- @param version string: Package version.
function deps.scan_deps(results, manifest, name, version, deps_mode)
   assert(type(results) == "table")
   assert(type(manifest) == "table")
   assert(type(name) == "string")
   assert(type(version) == "string")

   local fetch = require("luarocks.fetch")

   if results[name] then
      return
   end
   if not manifest.dependencies then manifest.dependencies = {} end
   local dependencies = manifest.dependencies
   if not dependencies[name] then dependencies[name] = {} end
   local dependencies_name = dependencies[name]
   local deplist = dependencies_name[version]
   local rockspec, err
   if not deplist then
      rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version), false)
      if not rockspec then
         util.printerr("Couldn't load rockspec for "..name.." "..version..": "..err)
         return
      end
      dependencies_name[version] = rockspec.dependencies
   else
      rockspec = {
         dependencies = deplist,
         rocks_provided = setmetatable({}, { __index = cfg.rocks_provided_3_0 })
      }
   end
   local matched = deps.match_deps(rockspec, nil, deps_mode)
   results[name] = version
   for _, match in pairs(matched) do
      deps.scan_deps(results, manifest, match.name, match.version, deps_mode)
   end
end

local valid_deps_modes = {
   one = true,
   order = true,
   all = true,
   none = true,
}

function deps.check_deps_mode_flag(flag)
   return valid_deps_modes[flag]
end

function deps.get_deps_mode(flags)
   if flags["deps-mode"] then
      return flags["deps-mode"]
   else
      return cfg.deps_mode
   end
end

return deps
