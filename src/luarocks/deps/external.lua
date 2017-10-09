local external = {}

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local fun = require("luarocks.fun")
local fs = require("luarocks.fs")
local util = require("luarocks.util")

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

local function list_dir_with_path(name)
   return fun.map(fs.list_dir(name), fun.string_prepend(name.."/"))
end

local function count_slashes(pathname)
   return #(pathname:gsub("[^/]", ""))
end

local function search_files(d, files)
   local errs = {}

   local patterns = {}
   for i, f in ipairs(files) do
      if f:match("%*") then
         patterns[i] = f:gsub("%.", "%%."):gsub("%*", ".*")
         table.insert(errs, "matching "..f.." in "..d)
      else
         table.insert(errs, f.." in "..d)
      end
   end
   
   local root_depth = count_slashes(d)

   local ok, name = fun.bfs(d, list_dir_with_path, function(name)
      if count_slashes(name) > root_depth + 4 then
         return false -- Limit recursion depth
      end
      if fs.is_dir(name) then
         return name
      end
      for i, f in ipairs(files) do
         if patterns[i] and dir.base_name(name):match(patterns[i]) then
            return true, dir.dir_name(name)
         elseif util.ends_with(name, "/"..f) then
            return true, name:sub(1, -(#f + 1))
         end
      end
      return false
   end)
   
   if ok then
      return name
   end
   return nil, errs
end

-- @param extdir directory prefix to search for external dependencies
-- (one entry from the `external_deps_dirs` configuration.)
-- It may be a table, containing fields `bin`, `include` and `lib`
-- (whose contents may be strings or lists of strings).
-- @param mode "install" or "build"
-- @return 
local function setup_tests(extdir, mode)
   local patterns, subdirs
   if mode == "install" then
      patterns = cfg.runtime_external_deps_patterns
      subdirs = cfg.runtime_external_deps_subdirs
   else
      patterns = cfg.external_deps_patterns
      subdirs = cfg.external_deps_subdirs
   end
   local tests = {
      BINDIR = { subdir = subdirs.bin, entry = "program", patterns = patterns.bin },
      INCDIR = { subdir = subdirs.include, entry = "header", patterns = patterns.include },
      LIBDIR = { subdir = subdirs.lib, entry = "library", patterns = patterns.lib }
   }
   local prefix
   if type(extdir) == "string" then
      prefix = extdir
   elseif type(extdir) == "table" then
      if extdir.bin then
         tests.BINDIR.subdir = extdir.bin
      end
      if extdir.include then
         if tests.INCDIR then
            tests.INCDIR.subdir = extdir.include
         end
      end
      if extdir.lib then
         tests.LIBDIR.subdir = extdir.lib
      end
      prefix = extdir.prefix
   end
   if mode == "install" then
      tests.INCDIR = nil
   end
   return prefix, tests
end

--- Decide on a list of paths to search, based on given inputs.
-- if an explicit varible is given, use that only. Otherwise,
-- construct paths based on given prefix and subdirs.
-- @param specific_var Value of specific variable
-- (e.g. the value of `OPENSSL_INCDIR`)
-- @param prefix Base prefix in use.
-- @param subdir (string or table) one or more subdirectories
-- to append to the prefix.
-- @return a list of paths to search.
local function get_paths_to_search(specific_var, prefix, subdir)
   if specific_var then
      return { specific_var }
   elseif type(subdir) == "table" then
      return fun.map(subdir, fun.curry(dir.path, prefix))
   else
      return { dir.path(prefix, subdir) }
   end
end

--- Search for one file in a given list of paths.
-- @param entry a value given for a `program`, `header` or `library`
-- in an `external_dependencies` item of a rockspec.
-- @param paths a list of paths to search.
-- @param patterns a list of patterns to use when producing
-- variants of a given entry. For example, entries "ssl" and
-- can "libssl.so" produce "libssl.a" or "ssl.dll" as well.
-- @return on success, the filename of the located file.
-- on failure, nil and a list of attempted pathnames.
local function search_entry(entry, paths, patterns)
   local tried = {}
   local files = {}
   if not entry:match("%.") then
   add_all_patterns(entry, patterns, files)
   else
      for _, pattern in ipairs(patterns) do
         local matched = deconstruct_pattern(entry, pattern)
         if matched then
            add_all_patterns(matched, patterns, files)
         end
      end
      table.insert(files, entry)
   end
   
   -- small convenience hack
   for i, f in ipairs(files) do
      if f:match("%.so$") or f:match("%.dylib$") or f:match("%.dll$") then
         files[i] = f:gsub("%.[^.]+$", "."..cfg.external_lib_extension)
      end
   end
   
   for _, d in ipairs(paths) do
      local where, errs = search_files(d, files)
      if where then
         if cfg.verbose then
            util.printout("Found dependency " .. entry .. " at " .. where)
         end
         return where
      else
         fun.concat_in(tried, errs)
      end
   end

   return nil, tried
end

--- Try to find the files specified in `entries` in the given directory.
-- @param extdir directory prefix to search for external dependencies
-- (one entry from the `external_deps_dirs` configuration.)
-- @param entries one item from the `external_dependencies` table,
-- containing entries with keys `program`, `header` and/or `library`.
-- @param mode "install" or "build"
-- @param vars a table of variables, with keys `DIR`, `INCDIR`, `BINDIR`,
-- `LIBDIR`; if present, these are the locations configured by the user.
local function try_entries_in_extdir(extdir, entries, mode, vars)
   local prefix, tests = setup_tests(extdir, mode)
   for testvar, testdata in util.sortedpairs(tests) do
      local paths = get_paths_to_search(vars[testvar], prefix, testdata.subdir)
      testdata.dir = paths[1]
      local entry = entries[testdata.entry]
      if entry then
         local found, errs = search_entry(entry, paths, testdata.patterns)
         if errs then
            return nil, nil, errs, testdata.entry
         end
         testdata.dir = found
      end
   end
   return prefix, tests
end

local entry_to_testvar = {
   program = "BINDIR",
   header = "INCDIR",
   library = "LIBDIR",
}

--- Check one dependency from the `external_dependencies` table,
-- updating the table of variables `vars` with the locations found.
-- @param entries one item from the `external_dependencies` table,
-- containing entries with keys `program`, `header` and/or `library`.
-- @param mode "install" or "build"
-- @param vars a table of variables, with keys `DIR`, `INCDIR`, `BINDIR`,
-- `LIBDIR`; if present, these are the locations configured by the user.
-- @return true on success; nil, a list of files unsucessfully searched
-- and a list of failed variables on error.
local function check_external_dep(entries, mode, vars)
   local failed_files = { program = {}, header = {}, library = {} }
   local failed_testvars = {}

   local extdirs = vars["DIR"] and { vars["DIR"] } or cfg.external_deps_dirs
   
   for _, extdir in ipairs(extdirs) do

      local prefix, tests, err_files, err_entry =
         try_entries_in_extdir(extdir, entries, mode, vars)

      if prefix then
         for testvar, testdata in pairs(tests) do
            vars[testvar] = testdata.dir
         end
         vars["DIR"] = prefix
         return true
      end
      fun.concat_in(failed_files[err_entry], err_files)
      table.insert(failed_testvars, entry_to_testvar[err_entry])
   end
   return nil, failed_files, failed_testvars
end

local function error_message(rockname, depname, failed_files, failed_vars)
   local errs = {}
   for entry, files in util.sortedpairs(failed_files) do
      if next(files) then
         table.insert(errs, "Could not find "..entry.." file for "..depname)
         for _, file in ipairs(fun.sort_uniq_in(files)) do
            table.insert(errs, "  No file "..file)
         end
      end
   end
   local dirs = { depname.."_DIR" }
   fun.concat_in(dirs,
                 fun.map(fun.sort_uniq_in(failed_vars),
                         fun.string_prepend(depname.."_")))
   table.insert(errs, "You may have to install "..depname.." in your system and/or pass "..table.concat(dirs, " or ").." to the luarocks command.")
   table.insert(errs, "Example: luarocks install "..rockname.." "..depname.."_DIR=/usr/local")
   return table.concat(errs, "\n")
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
function external.check_external_deps(rockspec, mode)
   assert(type(rockspec) == "table")

   if not rockspec.external_dependencies then
      return true
   end
   
   for name, entries in util.sortedpairs(rockspec.external_dependencies) do
      local vars = {
         DIR = rockspec.variables[name.."_DIR"],
         BINDIR = rockspec.variables[name.."_BINDIR"],
         INCDIR = rockspec.variables[name.."_INCDIR"],
         LIBDIR = rockspec.variables[name.."_LIBDIR"],
      }
      local ok, err_files, err_vars = check_external_dep(entries, mode, vars)
      if not ok then
         return nil, error_message(rockspec.name, name, err_files, err_vars), "dependency"
      end
      rockspec.variables[name.."_DIR"] = vars.DIR 
      rockspec.variables[name.."_BINDIR"] = vars.BINDIR
      rockspec.variables[name.."_INCDIR"] = vars.INCDIR
      rockspec.variables[name.."_LIBDIR"] = vars.LIBDIR
   end
   return true
end

return external
