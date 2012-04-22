
--- Dependency handling functions.
-- Dependencies are represented in LuaRocks through strings with
-- a package name followed by a comma-separated list of constraints.
-- Each constraint consists of an operator and a version number.
-- In this string format, version numbers are represented as
-- naturally as possible, like they are used by upstream projects
-- (e.g. "2.0beta3"). Internally, LuaRocks converts them to a purely
-- numeric representation, allowing comparison following some
-- "common sense" heuristics. The precise specification of the
-- comparison criteria is the source code of this module, but the
-- test/test_deps.lua file included with LuaRocks provides some
-- insights on what these criteria are.
module("luarocks.deps", package.seeall)

local cfg = require("luarocks.cfg")
local manif_core = require("luarocks.manif_core")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local util = require("luarocks.util")

local operators = {
   ["=="] = "==",
   ["~="] = "~=",
   [">"] = ">",
   ["<"] = "<",
   [">="] = ">=",
   ["<="] = "<=",
   ["~>"] = "~>",
   -- plus some convenience translations
   [""] = "==",
   ["="] = "==",
   ["!="] = "~="
}

local deltas = {
   scm =    1000,
   cvs =    1000,
   rc =    -1000,
   pre =   -10000,
   beta =  -100000,
   alpha = -1000000
}

local version_mt = {
   --- Equality comparison for versions.
   -- All version numbers must be equal.
   -- If both versions have revision numbers, they must be equal;
   -- otherwise the revision number is ignored.
   -- @param v1 table: version table to compare.
   -- @param v2 table: version table to compare.
   -- @return boolean: true if they are considered equivalent.
   __eq = function(v1, v2)
      if #v1 ~= #v2 then
         return false
      end
      for i = 1, #v1 do
         if v1[i] ~= v2[i] then
            return false
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision == v2.revision)
      end
      return true
   end,
   --- Size comparison for versions.
   -- All version numbers are compared.
   -- If both versions have revision numbers, they are compared;
   -- otherwise the revision number is ignored.
   -- @param v1 table: version table to compare.
   -- @param v2 table: version table to compare.
   -- @return boolean: true if v1 is considered lower than v2.
   __lt = function(v1, v2)
      for i = 1, math.max(#v1, #v2) do
         local v1i, v2i = v1[i] or 0, v2[i] or 0
         if v1i ~= v2i then
            return (v1i < v2i)
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision < v2.revision)
      end
      return false
   end
}

local version_cache = {}
setmetatable(version_cache, {
   __mode = "kv"
})

--- Parse a version string, converting to table format.
-- A version table contains all components of the version string
-- converted to numeric format, stored in the array part of the table.
-- If the version contains a revision, it is stored numerically
-- in the 'revision' field. The original string representation of
-- the string is preserved in the 'string' field.
-- Returned version tables use a metatable
-- allowing later comparison through relational operators.
-- @param vstring string: A version number in string format.
-- @return table or nil: A version table or nil
-- if the input string contains invalid characters.
function parse_version(vstring)
   if not vstring then return nil end
   assert(type(vstring) == "string")

   local cached = version_cache[vstring]
   if cached then
      return cached
   end

   local version = {}
   local i = 1

   local function add_token(number)
      version[i] = version[i] and version[i] + number/100000 or number
      i = i + 1
   end
   
   -- trim leading and trailing spaces
   vstring = vstring:match("^%s*(.*)%s*$")
   version.string = vstring
   -- store revision separately if any
   local main, revision = vstring:match("(.*)%-(%d+)$")
   if revision then
      vstring = main
      version.revision = tonumber(revision)
   end
   while #vstring > 0 do
      -- extract a number
      local token, rest = vstring:match("^(%d+)[%.%-%_]*(.*)")
      if token then
         add_token(tonumber(token))
      else
         -- extract a word
         token, rest = vstring:match("^(%a+)[%.%-%_]*(.*)")
         if not token then
            util.printerr("Warning: version number '"..vstring.."' could not be parsed.")
            version[i] = 0
            break
         end
         local last = #version
         version[i] = deltas[token] or (token:byte() / 1000)
      end
      vstring = rest
   end
   setmetatable(version, version_mt)
   version_cache[vstring] = version
   return version
end

--- Utility function to compare version numbers given as strings.
-- @param a string: one version.
-- @param b string: another version.
-- @return boolean: True if a > b.
function compare_versions(a, b)
   return parse_version(a) > parse_version(b)
end

--- Consumes a constraint from a string, converting it to table format.
-- For example, a string ">= 1.0, > 2.0" is converted to a table in the
-- format {op = ">=", version={1,0}} and the rest, "> 2.0", is returned
-- back to the caller.
-- @param input string: A list of constraints in string format.
-- @return (table, string) or nil: A table representing the same
-- constraints and the string with the unused input, or nil if the
-- input string is invalid.
local function parse_constraint(input)
   assert(type(input) == "string")

   local no_upgrade, op, version, rest = input:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
   op = operators[op]
   version = parse_version(version)
   if not op or not version then return nil end
   return { op = op, version = version, no_upgrade = no_upgrade=="@" and true or nil }, rest
end

--- Convert a list of constraints from string to table format.
-- For example, a string ">= 1.0, < 2.0" is converted to a table in the format
-- {{op = ">=", version={1,0}}, {op = "<", version={2,0}}}.
-- Version tables use a metatable allowing later comparison through
-- relational operators.
-- @param input string: A list of constraints in string format.
-- @return table or nil: A table representing the same constraints,
-- or nil if the input string is invalid.
function parse_constraints(input)
   assert(type(input) == "string")

   local constraints, constraint = {}, nil
   while #input > 0 do
      constraint, input = parse_constraint(input)
      if constraint then
         table.insert(constraints, constraint)
      else
         return nil
      end
   end
   return constraints
end

--- Convert a dependency from string to table format.
-- For example, a string "foo >= 1.0, < 2.0"
-- is converted to a table in the format
-- {name = "foo", constraints = {{op = ">=", version={1,0}},
-- {op = "<", version={2,0}}}}. Version tables use a metatable
-- allowing later comparison through relational operators.
-- @param dep string: A dependency in string format
-- as entered in rockspec files.
-- @return table or nil: A table representing the same dependency relation,
-- or nil if the input string is invalid.
function parse_dep(dep)
   assert(type(dep) == "string")

   local name, rest = dep:match("^%s*([a-zA-Z][a-zA-Z0-9%.%-%_]*)%s*(.*)")
   if not name then return nil end
   local constraints = parse_constraints(rest)
   if not constraints then return nil end
   return { name = name, constraints = constraints }
end

--- Convert a version table to a string.
-- @param v table: The version table
-- @param internal boolean or nil: Whether to display versions in their
-- internal representation format or how they were specified.
-- @return string: The dependency information pretty-printed as a string.
function show_version(v, internal)
   assert(type(v) == "table")
   assert(type(internal) == "boolean" or not internal)

   return (internal
           and table.concat(v, ":")..(v.revision and tostring(v.revision) or "")
           or v.string)
end

--- Convert a dependency in table format to a string.
-- @param dep table: The dependency in table format
-- @param internal boolean or nil: Whether to display versions in their
-- internal representation format or how they were specified.
-- @return string: The dependency information pretty-printed as a string.
function show_dep(dep, internal)
   assert(type(dep) == "table")
   assert(type(internal) == "boolean" or not internal)
   
   local pretty = {}
   for _, c in ipairs(dep.constraints) do
      table.insert(pretty, c.op .. " " .. show_version(c.version, internal))
   end
   return dep.name.." "..table.concat(pretty, ", ")
end

--- A more lenient check for equivalence between versions.
-- This returns true if the requested components of a version
-- match and ignore the ones that were not given. For example,
-- when requesting "2", then "2", "2.1", "2.3.5-9"... all match.
-- When requesting "2.1", then "2.1", "2.1.3" match, but "2.2"
-- doesn't.
-- @param version string or table: Version to be tested; may be
-- in string format or already parsed into a table.
-- @param requested string or table: Version requested; may be
-- in string format or already parsed into a table.
-- @return boolean: True if the tested version matches the requested
-- version, false otherwise.
local function partial_match(version, requested)
   assert(type(version) == "string" or type(version) == "table")
   assert(type(requested) == "string" or type(version) == "table")

   if type(version) ~= "table" then version = parse_version(version) end
   if type(requested) ~= "table" then requested = parse_version(requested) end
   if not version or not requested then return false end
   
   for i, ri in ipairs(requested) do
      local vi = version[i] or 0
      if ri ~= vi then return false end
   end
   if requested.revision then
      return requested.revision == version.revision
   end
   return true
end

--- Check if a version satisfies a set of constraints.
-- @param version table: A version in table format
-- @param constraints table: An array of constraints in table format.
-- @return boolean: True if version satisfies all constraints,
-- false otherwise.
function match_constraints(version, constraints)
   assert(type(version) == "table")
   assert(type(constraints) == "table")
   local ok = true
   setmetatable(version, version_mt)
   for _, constr in pairs(constraints) do
      local constr_version = constr.version
      setmetatable(constr.version, version_mt)
      if     constr.op == "==" then ok = version == constr_version
      elseif constr.op == "~=" then ok = version ~= constr_version
      elseif constr.op == ">"  then ok = version >  constr_version
      elseif constr.op == "<"  then ok = version <  constr_version
      elseif constr.op == ">=" then ok = version >= constr_version
      elseif constr.op == "<=" then ok = version <= constr_version
      elseif constr.op == "~>" then ok = partial_match(version, constr_version)
      end
      if not ok then break end
   end
   return ok
end

--- Attempt to match a dependency to an installed rock.
-- @param dep table: A dependency parsed in table format.
-- @param blacklist table: Versions that can't be accepted. Table where keys
-- are program versions and values are 'true'.
-- @return table or nil: A table containing fields 'name' and 'version'
-- representing an installed rock which matches the given dependency,
-- or nil if it could not be matched.
local function match_dep(dep, blacklist)
   assert(type(dep) == "table")

   local versions
   if dep.name == "lua" then
      versions = { cfg.lua_version }
   else
      versions = manif_core.get_versions(dep.name)
   end
   if not versions then
      return nil
   end
   if blacklist then
      local i = 1
      while versions[i] do
         if blacklist[versions[i]] then
            table.remove(versions, i)
         else
            i = i + 1
         end
      end
   end
   local candidates = {}
   for _, vstring in ipairs(versions) do
      local version = parse_version(vstring)
      if match_constraints(version, dep.constraints) then
         table.insert(candidates, version)
      end
   end
   if #candidates == 0 then
      return nil
   else
      table.sort(candidates)
      return {
         name = dep.name,
         version = candidates[#candidates].string
      }
   end
end

--- Attempt to match dependencies of a rockspec to installed rocks.
-- @param rockspec table: The rockspec loaded as a table.
-- @param blacklist table or nil: Program versions to not use as valid matches.
-- Table where keys are program names and values are tables where keys
-- are program versions and values are 'true'.
-- @return table, table: A table where keys are dependencies parsed
-- in table format and values are tables containing fields 'name' and
-- version' representing matches, and a table of missing dependencies
-- parsed as tables.
function match_deps(rockspec, blacklist)
   assert(type(rockspec) == "table")
   assert(type(blacklist) == "table" or not blacklist)
   local matched, missing, no_upgrade = {}, {}, {}

   for _, dep in ipairs(rockspec.dependencies) do
      local found = match_dep(dep, blacklist and blacklist[dep.name] or nil)
      if found then
         if dep.name ~= "lua" then 
            matched[dep] = found
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

--- Check dependencies of a rock and attempt to install any missing ones.
-- Packages are installed using the LuaRocks "install" command.
-- Aborts the program if a dependency could not be fulfilled.
-- @param rockspec table: A rockspec in table format.
-- @return boolean or (nil, string, [string]): True if no errors occurred, or
-- nil and an error message if any test failed, followed by an optional
-- error code.
function fulfill_dependencies(rockspec)

   local search = require("luarocks.search")
   local install = require("luarocks.install")

   if rockspec.supported_platforms then
      if not platforms_set then
         platforms_set = values_set(cfg.platforms)
      end
      local supported = nil
      for _, plat in pairs(rockspec.supported_platforms) do
         local neg, plat = plat:match("^(!?)(.*)")
         if neg == "!" then
            if platforms_set[plat] then
               return nil, "This rockspec for "..rockspec.package.." does not support "..plat.." platforms."
            end
         else
            if platforms_set[plat] then
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

   local matched, missing, no_upgrade = match_deps(rockspec)

   if next(no_upgrade) then
      util.printerr("Missing dependencies for "..rockspec.name.." "..rockspec.version..":")
      for _, dep in pairs(no_upgrade) do
         util.printerr(show_dep(dep))
      end
      if next(missing) then
         for _, dep in pairs(missing) do
            util.printerr(show_dep(dep))
         end
      end
      util.printerr()
      for _, dep in pairs(no_upgrade) do
         util.printerr("This version of "..rockspec.name.." is designed for use with")
         util.printerr(show_dep(dep)..", but is configured to avoid upgrading it")
         util.printerr("automatically. Please upgrade "..dep.name.." with")
         util.printerr("   luarocks install "..dep.name)
         util.printerr("or choose an older version of "..rockspec.name.." with")
         util.printerr("   luarocks search "..rockspec.name)
      end
      return nil, "Failed matching dependencies."
   end

   if next(missing) then
      util.printerr()
      util.printerr("Missing dependencies for "..rockspec.name..":")
      for _, dep in pairs(missing) do
         util.printerr(show_dep(dep))
      end
      util.printerr()

      for _, dep in pairs(missing) do
         -- Double-check in case dependency was filled during recursion.
         if not match_dep(dep) then
            local rock = search.find_suitable_rock(dep)
            if not rock then
               return nil, "Could not satisfy dependency: "..show_dep(dep)
            end
            local ok, err, errcode = install.run(rock)
            if not ok then
               return nil, "Failed installing dependency: "..rock.." - "..err, errcode
            end
         end
      end
   end
   return true
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
function check_external_deps(rockspec, mode)
   assert(type(rockspec) == "table")

   local fs = require("luarocks.fs")
   
   local vars = rockspec.variables
   local patterns = cfg.external_deps_patterns
   local subdirs = cfg.external_deps_subdirs
   if mode == "install" then
      patterns = cfg.runtime_external_deps_patterns
      subdirs = cfg.runtime_external_deps_subdirs
   end
   if rockspec.external_dependencies then
      for name, files in pairs(rockspec.external_dependencies) do
         local ok = true
         local failed_file = nil
         local failed_dirname = nil
         for _, extdir in ipairs(cfg.external_deps_dirs) do
            ok = true
            local prefix = vars[name.."_DIR"]
            local dirs = {
               BINDIR = { subdir = subdirs.bin, testfile = "program", pattern = patterns.bin },
               INCDIR = { subdir = subdirs.include, testfile = "header", pattern = patterns.include },
               LIBDIR = { subdir = subdirs.lib, testfile = "library", pattern = patterns.lib }
            }
            if mode == "install" then
               dirs.INCDIR = nil
            end
            if not prefix then
               prefix = extdir
            end
            if type(prefix) == "table" then
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
               prefix = prefix.prefix
            end
            for dirname, dirdata in pairs(dirs) do
               dirdata.dir = vars[name.."_"..dirname] or dir.path(prefix, dirdata.subdir)
               local file = files[dirdata.testfile]
               if file then
                  local files = {}
                  if not file:match("%.") then
                     for _, pattern in ipairs(dirdata.pattern) do
                        table.insert(files, (pattern:gsub("?", file)))
                     end
                  else
                     table.insert(files, file)
                  end
                  local found = false
                  failed_file = nil
                  for _, f in pairs(files) do
                     -- small convenience hack
                     if f:match("%.so$") or f:match("%.dylib$") or f:match("%.dll$") then
                        f = f:gsub("%.[^.]+$", "."..cfg.external_lib_extension)
                     end
                     if f:match("%*") then
                        local replaced = f:gsub("%.", "%%."):gsub("%*", ".*")
                        for _, entry in ipairs(fs.list_dir(dirdata.dir)) do
                           if entry:match(replaced) then
                              found = true
                              break
                           end
                        end
                     else
                        found = fs.is_file(dir.path(dirdata.dir, f))
                     end
                     if found then
                        break
                     else
                        if failed_file then
                           failed_file = failed_file .. ", or " .. f
                        else
                           failed_file = f
                        end
                     end
                  end
                  if not found then
                     ok = false
                     failed_dirname = dirname
                     break
                  end
               end
            end
            if ok then
               for dirname, dirdata in pairs(dirs) do
                  vars[name.."_"..dirname] = dirdata.dir
               end
               vars[name.."_DIR"] = prefix
               break
            end
         end
         if not ok then
            return nil, "Could not find expected file "..failed_file.." for "..name.." -- you may have to install "..name.." in your system and/or pass "..name.."_DIR or "..name.."_"..failed_dirname.." to the luarocks command. Example: luarocks install "..rockspec.name.." "..name.."_DIR=/usr/local", "dependency"
         end
      end
   end
   return true
end

--- Recursively scan dependencies, to build a transitive closure of all
-- dependent packages.
-- @param results table: The results table being built.
-- @param missing table: The table of missing dependencies being recursively built.
-- @param manifest table: The manifest table containing dependencies.
-- @param name string: Package name.
-- @param version string: Package version.
-- @return (table, table): The results and a table of missing dependencies.
function scan_deps(results, missing, manifest, name, version)
   assert(type(results) == "table")
   assert(type(missing) == "table")
   assert(type(manifest) == "table")
   assert(type(name) == "string")
   assert(type(version) == "string")

   local fetch = require("luarocks.fetch")

   local err
   if results[name] then
      return results, missing
   end
   if not manifest.dependencies then manifest.dependencies = {} end
   local dependencies = manifest.dependencies
   if not dependencies[name] then dependencies[name] = {} end
   local dependencies_name = dependencies[name]
   local deplist = dependencies_name[version]
   local rockspec, err
   if not deplist then
      rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version))
      if err then
         missing[name.." "..version] = err
         return results, missing
      end
      dependencies_name[version] = rockspec.dependencies
   else
      rockspec = { dependencies = deplist }
   end
   local matched, failures = match_deps(rockspec)
   for _, match in pairs(matched) do
      results, missing = scan_deps(results, missing, manifest, match.name, match.version)
   end
   if next(failures) then
      for _, failure in pairs(failures) do
         missing[show_dep(failure)] = "failed"
      end
   end
   results[name] = version
   return results, missing
end
