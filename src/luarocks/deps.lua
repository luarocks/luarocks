
--- High-level dependency related functions.
local deps = {}

local cfg = require("luarocks.core.cfg")
local manif = require("luarocks.manif")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local fun = require("luarocks.fun")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")
local queries = require("luarocks.queries")
local builtin = require("luarocks.build.builtin")

--- Attempt to match a dependency to an installed rock.
-- @param dep table: A dependency parsed in table format.
-- @param blacklist table: Versions that can't be accepted. Table where keys
-- are program versions and values are 'true'.
-- @param rocks_provided table: A table of auto-provided dependencies.
-- by this Lua implementation for the given dependency.
-- @return string or nil: latest installed version of the rock matching the dependency
-- or nil if it could not be matched.
local function match_dep(dep, blacklist, deps_mode, rocks_provided)
   assert(type(dep) == "table")
   assert(type(rocks_provided) == "table")
  
   local versions, locations
   local provided = rocks_provided[dep.name]
   if provided then
      -- Provided rocks have higher priority than manifest's rocks.
      versions, locations = { provided }, {}
   else
      versions, locations = manif.get_versions(dep, deps_mode)
   end

   local latest_version
   local latest_vstring
   for _, vstring in ipairs(versions) do
      if not blacklist or not blacklist[vstring] then
         local version = vers.parse_version(vstring)
         if vers.match_constraints(version, dep.constraints) then
            if not latest_version or version > latest_version then
               latest_version = version
               latest_vstring = vstring
            end
         end
      end
   end
   return latest_vstring, locations[latest_vstring]
end

--- Attempt to match dependencies of a rockspec to installed rocks.
-- @param dependencies table: The table of dependencies.
-- @param rocks_provided table: The table of auto-provided dependencies.
-- @param blacklist table or nil: Program versions to not use as valid matches.
-- Table where keys are program names and values are tables where keys
-- are program versions and values are 'true'.
-- @return table, table, table: A table where keys are dependencies parsed
-- in table format and values are tables containing fields 'name' and
-- version' representing matches; a table of missing dependencies
-- parsed as tables; and a table of "no-upgrade" missing dependencies
-- (to be used in plugin modules so that a plugin does not force upgrade of
-- its parent application).
function deps.match_deps(dependencies, rocks_provided, blacklist, deps_mode)
   assert(type(blacklist) == "table" or not blacklist)
   local matched, missing, no_upgrade = {}, {}, {}
   
   for _, dep in ipairs(dependencies) do
      local found = match_dep(dep, blacklist and blacklist[dep.name] or nil, deps_mode, rocks_provided)
      if found then
         if not rocks_provided[dep.name] then
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
   local installed = match_dep(queries.new(name), nil, deps_mode, rocks_provided)
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
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(dependencies) == "table")
   assert(type(deps_mode) == "string")
   assert(type(rocks_provided) == "table")

   local first_missing_dep = true

   for _, dep in ipairs(dependencies) do
      if not match_dep(dep, nil, deps_mode, rocks_provided) then
         if first_missing_dep then
            util.printout(("Missing dependencies for %s %s:"):format(name, version))
            first_missing_dep = false
         end

         util.printout(("   %s (%s)"):format(tostring(dep), rock_status(dep.name, deps_mode, rocks_provided)))
      end
   end
end

function deps.fulfill_dependency(dep, deps_mode, name, version, rocks_provided, verify)
   assert(dep:type() == "query")
   assert(type(deps_mode) == "string" or deps_mode == nil)
   assert(type(name) == "string" or name == nil)
   assert(type(version) == "string" or version == nil)
   assert(type(rocks_provided) == "table" or rocks_provided == nil)
   assert(type(verify) == "boolean" or verify == nil)
   deps_mode = deps_mode or "all"
   rocks_provided = rocks_provided or {}

   local found, where = match_dep(dep, nil, deps_mode, rocks_provided)
   if found then
      return true, found, where
   end

   local search = require("luarocks.search")
   local install = require("luarocks.cmd.install")

   if name and version then
      util.printout(("%s %s depends on %s (%s)"):format(
         name, version, tostring(dep), rock_status(dep.name, deps_mode, rocks_provided)))
   else
      util.printout(("Fulfilling dependency on %s (%s)"):format(
         tostring(dep), rock_status(dep.name, deps_mode, rocks_provided)))
   end
   
   if dep.constraints[1] and dep.constraints[1].no_upgrade then
      util.printerr("This version of "..name.." is designed for use with")
      util.printerr(tostring(dep)..", but is configured to avoid upgrading it")
      util.printerr("automatically. Please upgrade "..dep.name.." with")
      util.printerr("   luarocks install "..dep.name)
      util.printerr("or choose an older version of "..name.." with")
      util.printerr("   luarocks search "..name)
      return nil, "Failed matching dependencies"
   end

   local url, search_err = search.find_suitable_rock(dep, true)
   if not url then
      return nil, "Could not satisfy dependency "..tostring(dep)..": "..search_err
   end
   util.printout("Installing "..url)
   local install_flags = {
      deps_mode = deps_mode,
      namespace = dep.namespace,
      verify = verify,
   }
   local ok, install_err, errcode = install.command(install_flags, url)
   if not ok then
      return nil, "Failed installing dependency: "..url.." - "..install_err, errcode
   end

   found, where = match_dep(dep, nil, deps_mode, rocks_provided)
   assert(found)
   return true, found, where
end

--- Check dependencies of a rock and attempt to install any missing ones.
-- Packages are installed using the LuaRocks "install" command.
-- Aborts the program if a dependency could not be fulfilled.
-- @param rockspec table: A rockspec in table format.
-- @param depskey string: Rockspec key to fetch to get dependency table.
-- @param deps_mode string
-- @param verify boolean
-- @return boolean or (nil, string, [string]): True if no errors occurred, or
-- nil and an error message if any test failed, followed by an optional
-- error code.
function deps.fulfill_dependencies(rockspec, depskey, deps_mode, verify)
   assert(type(rockspec) == "table")
   assert(type(depskey) == "string")
   assert(type(deps_mode) == "string")
   assert(type(verify) == "boolean" or verify == nil)

   if rockspec.supported_platforms and next(rockspec.supported_platforms) then
      local all_negative = true
      local supported = false
      for _, plat in pairs(rockspec.supported_platforms) do
         local neg
         neg, plat = plat:match("^(!?)(.*)")
         if neg == "!" then
            if cfg.is_platform(plat) then
               return nil, "This rockspec for "..rockspec.package.." does not support "..plat.." platforms."
            end
         else
            all_negative = false
            if cfg.is_platform(plat) then
               supported = true
               break
            end
         end
      end
      if supported == false and not all_negative then
         local plats = cfg.print_platforms()
         return nil, "This rockspec for "..rockspec.package.." does not support "..plats.." platforms."
      end
   end

   deps.report_missing_dependencies(rockspec.name, rockspec.version, rockspec[depskey], deps_mode, rockspec.rocks_provided)

   util.printout()
   for _, dep in ipairs(rockspec[depskey]) do
      local ok, err = deps.fulfill_dependency(dep, deps_mode, rockspec.name, rockspec.version, rockspec.rocks_provided, verify)
      if not ok then
         return nil, err
      end
   end

   return true
end

--- If filename matches a pattern, return the capture.
-- For example, given "libfoo.so" and "lib?.so" is a pattern,
-- returns "foo" (which can then be used to build names
-- based on other patterns.
-- @param file string: a filename
-- @param pattern string: a pattern, where ? is to be matched by the filename.
-- @return string The pattern, if found, or nil.
local function deconstruct_pattern(file, pattern)
   local depattern = "^"..(pattern:gsub("%.", "%%."):gsub("%*", ".*"):gsub("?", "(.*)")).."$"
   return (file:match(depattern))
end

--- Construct all possible patterns for a name and add to the files array.
-- Run through the patterns array replacing all occurrences of "?"
-- with the given file name and store them in the files array.
-- @param file string A raw name (e.g. "foo")
-- @param array of string An array of patterns with "?" as the wildcard
-- (e.g. {"?.so", "lib?.so"})
-- @param files The array of constructed names
local function add_all_patterns(file, patterns, files)
   for _, pattern in ipairs(patterns) do
      table.insert(files, (pattern:gsub("?", file)))
   end
end

local function get_external_deps_dirs(mode)
   local patterns = cfg.external_deps_patterns
   local subdirs = cfg.external_deps_subdirs
   if mode == "install" then
      patterns = cfg.runtime_external_deps_patterns
      subdirs = cfg.runtime_external_deps_subdirs
   end
   local dirs = {
      BINDIR = { subdir = subdirs.bin, testfile = "program", pattern = patterns.bin },
      INCDIR = { subdir = subdirs.include, testfile = "header", pattern = patterns.include },
      LIBDIR = { subdir = subdirs.lib, testfile = "library", pattern = patterns.lib }
   }
   if mode == "install" then
      dirs.INCDIR = nil
   end
   return dirs
end

local function resolve_prefix(prefix, dirs)
   if type(prefix) == "string" then
      return prefix
   elseif type(prefix) == "table" then
      if prefix.bin then
         dirs.BINDIR.subdir = prefix.bin
      end
      if prefix.include then
         if dirs.INCDIR then
            dirs.INCDIR.subdir = prefix.include
         end
      end
      if prefix.lib then
         dirs.LIBDIR.subdir = prefix.lib
      end
      return prefix.prefix
   end
end

local function check_external_dependency_at(prefix, name, ext_files, vars, dirs, err_files, cache)
   local fs = require("luarocks.fs")
   cache = cache or {}

   for dirname, dirdata in util.sortedpairs(dirs) do
      local paths
      local path_var_value = vars[name.."_"..dirname]
      if path_var_value then
         paths = { path_var_value }
      elseif type(dirdata.subdir) == "table" then
         paths = {}
         for i,v in ipairs(dirdata.subdir) do
            paths[i] = dir.path(prefix, v)
         end
      else
         paths = { dir.path(prefix, dirdata.subdir) }
      end
      dirdata.dir = paths[1]
      local file = ext_files[dirdata.testfile]
      if file then
         local files = {}
         -- If it doesn't look like it contains a filename extension
         if not (file:match("%.[a-z]+$") or file:match("%.[a-z]+%.")) then
            add_all_patterns(file, dirdata.pattern, files)
         else
            for _, pattern in ipairs(dirdata.pattern) do
               local matched = deconstruct_pattern(file, pattern)
               if matched then
                  add_all_patterns(matched, dirdata.pattern, files)
               end
            end
            table.insert(files, file)
         end
         local found = false
         for _, f in ipairs(files) do

            -- small convenience hack
            if f:match("%.so$") or f:match("%.dylib$") or f:match("%.dll$") then
               f = f:gsub("%.[^.]+$", "."..cfg.external_lib_extension)
            end

            local pattern
            if f:match("%*") then
               pattern = f:gsub("([-.+])", "%%%1"):gsub("%*", ".*")
               f = "matching "..f
            end

            for _, d in ipairs(paths) do
               if pattern then
                  if not cache[d] then
                     cache[d] = fs.list_dir(d)
                  end
                  for _, entry in ipairs(cache[d]) do
                     if entry:match(pattern) then
                        found = true
                        break
                     end
                  end
               else
                  found = fs.is_file(dir.path(d, f))
               end
               if found then
                  dirdata.dir = d
                  dirdata.file = f
                  break
               else
                  table.insert(err_files[dirdata.testfile], f.." in "..d)
               end
            end
            if found then
               break
            end
         end
         if not found then
            return nil, dirname, dirdata.testfile
         end
      end
   end

   for dirname, dirdata in pairs(dirs) do
      vars[name.."_"..dirname] = dirdata.dir
      vars[name.."_"..dirname.."_FILE"] = dirdata.file
   end
   vars[name.."_DIR"] = prefix
   return true
end

local function check_external_dependency(name, ext_files, vars, mode, cache)
   local ok
   local err_dirname
   local err_testfile
   local err_files = {program = {}, header = {}, library = {}}

   local dirs = get_external_deps_dirs(mode)
   
   local prefixes
   if vars[name .. "_DIR"] then
      prefixes = { vars[name .. "_DIR"] }
   else
      prefixes = cfg.external_deps_dirs
   end
   
   for _, prefix in ipairs(prefixes) do
      prefix = resolve_prefix(prefix, dirs)
      if cfg.is_platform("mingw32") and name == "LUA" then
         dirs.LIBDIR.pattern = fun.filter(util.deep_copy(dirs.LIBDIR.pattern), function(s)
            return not s:match("%.a$")
         end)
      end
      ok, err_dirname, err_testfile = check_external_dependency_at(prefix, name, ext_files, vars, dirs, err_files, cache)
      if ok then
         return true
      end
   end
   
   return nil, err_dirname, err_testfile, err_files
end

--- Set up path-related variables for external dependencies.
-- For each key in the external_dependencies table in the
-- rockspec file, four variables are created: <key>_DIR, <key>_BINDIR,
-- <key>_INCDIR and <key>_LIBDIR. These are not overwritten
-- if already set (e.g. by the LuaRocks config file or through the
-- command-line). Values in the external_dependencies table
-- are tables that may contain a "header" or a "library" field,
-- with filenames to be tested for existence.
-- @param rockspec table: The rockspec table.
-- @param mode string: if "build" is given, checks all files;
-- if "install" is given, do not scan for headers.
-- @return boolean or (nil, string): True if no errors occurred, or
-- nil and an error message if any test failed.
function deps.check_external_deps(rockspec, mode)
   assert(rockspec:type() == "rockspec")
   
   if not rockspec.external_dependencies then
      rockspec.external_dependencies = builtin.autodetect_external_dependencies(rockspec.build)
   end
   if not rockspec.external_dependencies then
      return true
   end

   for name, ext_files in util.sortedpairs(rockspec.external_dependencies) do
      local ok, err_dirname, err_testfile, err_files = check_external_dependency(name, ext_files, rockspec.variables, mode)
      if not ok then
         local lines = {"Could not find "..err_testfile.." file for "..name}
      
         local err_paths = {}
         for _, err_file in ipairs(err_files[err_testfile]) do
            if not err_paths[err_file] then
               err_paths[err_file] = true
               table.insert(lines, "  No file "..err_file)
            end
         end
      
         table.insert(lines, "You may have to install "..name.." in your system and/or pass "..name.."_DIR or "..name.."_"..err_dirname.." to the luarocks command.")
         table.insert(lines, "Example: luarocks install "..rockspec.name.." "..name.."_DIR=/usr/local")
      
         return nil, table.concat(lines, "\n"), "dependency"
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
   assert(type(name) == "string" and not name:match("/"))
   assert(type(version) == "string")

   local fetch = require("luarocks.fetch")

   if results[name] then
      return
   end
   if not manifest.dependencies then manifest.dependencies = {} end
   local md = manifest.dependencies
   if not md[name] then md[name] = {} end
   local mdn = md[name]
   local dependencies = mdn[version]
   local rocks_provided
   if not dependencies then
      local rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version), false)
      if not rockspec then
         util.printerr("Couldn't load rockspec for "..name.." "..version..": "..err)
         return
      end
      dependencies = rockspec.dependencies
      rocks_provided = rockspec.rocks_provided
      mdn[version] = dependencies
   else
      rocks_provided = setmetatable({}, { __index = cfg.rocks_provided_3_0 })
   end
   local matched = deps.match_deps(dependencies, rocks_provided, nil, deps_mode)
   results[name] = version
   for _, match in pairs(matched) do
      deps.scan_deps(results, manifest, match.name, match.version, deps_mode)
   end
end

local function find_lua_incdir(prefix, luaver, luajitver)
   luajitver = luajitver and luajitver:gsub("%-.*", "")
   local shortv = luaver:gsub("%.", "")
   local incdirs = {
      prefix .. "/include/lua/" .. luaver,
      prefix .. "/include/lua" .. luaver,
      prefix .. "/include/lua" .. shortv,
      prefix .. "/include",
      prefix,
      luajitver and prefix .. "/include/luajit-" .. luajitver:match("^(%d+%.%d+)"),
   }
   for _, d in ipairs(incdirs) do
      local lua_h = dir.path(d, "lua.h")
      local fd = io.open(lua_h)
      if fd then
         -- TODO check that LUA_VERSION_MAJOR and LUA_VERSION_MINOR match luaver
         fd:close()
         return d
      end
   end

   -- not found, will fallback to a default
   return nil
end

function deps.check_lua(vars)
   local incdir_found = true
   if (not vars.LUA_INCDIR) and vars.LUA_DIR then
      vars.LUA_INCDIR = find_lua_incdir(vars.LUA_DIR, cfg.lua_version, cfg.luajit_version)
      incdir_found = (vars.LUA_INCDIR ~= nil)
   end
   local shortv = cfg.lua_version:gsub("%.", "")
   local libnames = {
      "lua" .. cfg.lua_version,
      "lua" .. shortv,
      "lua-" .. cfg.lua_version,
      "lua-" .. shortv,
      "lua",
   }
   if cfg.luajit_version then
      table.insert(libnames, 1, "luajit-" .. cfg.lua_version)
   end
   local cache = {}
   for _, libname in ipairs(libnames) do
      local ok = check_external_dependency("LUA", { library = libname }, vars, "build", cache)
      if ok then
         vars.LUALIB = vars.LUA_LIBDIR_FILE
         return true
      end
   end
   if not incdir_found then
      return nil, "Failed finding Lua header files. You may need to install them or configure LUA_INCDIR.", "dependency"
   end
   return nil, "Failed finding Lua library. You may need to configure LUA_LIBDIR.", "dependency"
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
