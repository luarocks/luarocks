
--- Module implementing the LuaRocks "search" command.
-- Queries LuaRocks servers.
module("luarocks.search", package.seeall)

local dir = require("luarocks.dir")
local path = require("luarocks.path")
local manif = require("luarocks.manif")
local deps = require("luarocks.deps")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")

help_summary = "Query the LuaRocks servers."
help_arguments = "[--source] [--binary] { <name> [<version>] | --all }"
help = [[
--source  Return only rockspecs and source rocks,
          to be used with the "build" command.
--binary  Return only pure Lua and binary rocks (rocks that can be used
          with the "install" command without requiring a C toolchain).
--all     List all contents of the server that are suitable to
          this platform, do not filter by name.
]]

--- Convert the arch field of a query table to table format.
-- @param query table: A query table.
local function query_arch_as_table(query)
   local format = type(query.arch)
   if format == "table" then
      return
   elseif format == "nil" then
      local accept = {}
      accept["src"] = true
      accept["all"] = true
      accept["rockspec"] = true
      accept["installed"] = true
      accept[cfg.arch] = true
      query.arch = accept
   elseif format == "string" then
      local accept = {}
      for a in query.arch:gmatch("[%w_-]+") do
         accept[a] = true
      end
      query.arch = accept
   end
end

--- Store a search result (a rock or rockspec) in the results table.
-- @param results table: The results table, where keys are package names and
-- versions are tables matching version strings to an array of servers.
-- @param name string: Package name.
-- @param version string: Package version.
-- @param arch string: Architecture of rock ("all", "src" or platform
-- identifier), "rockspec" or "installed"
-- @param repo string: Pathname of a local repository of URL of
-- rocks server.
local function store_result(results, name, version, arch, repo)
   assert(type(results) == "table")
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(arch) == "string")
   assert(type(repo) == "string")
   
   if not results[name] then results[name] = {} end
   if not results[name][version] then results[name][version] = {} end
   table.insert(results[name][version], {
      arch = arch,
      repo = repo
   })
end

--- Test the name field of a query.
-- If query has a boolean field exact_name set to false,
-- then substring match is performed; otherwise, exact string
-- comparison is done.
-- @param query table: A query in dependency table format.
-- @param name string: A package name.
-- @return boolean: True if names match, false otherwise.
local function match_name(query, name)
   assert(type(query) == "table")
   assert(type(name) == "string")
   if query.exact_name == false then
      return name:find(query.name, 0, true) and true or false
   else
      return name == query.name
   end
end

--- Store a match in a results table if version matches query.
-- Name, version, arch and repository path are stored in a given
-- table, optionally checking if version and arch (if given) match
-- a query.
-- @param results table: The results table, where keys are package names and
-- versions are tables matching version strings to an array of servers.
-- @param repo string: URL or pathname of the repository.
-- @param name string: The name of the package being tested.
-- @param version string: The version of the package being tested.
-- @param arch string: The arch of the package being tested.
-- @param query table: A table describing the query in dependency
-- format (for example, {name = "filesystem", exact_name = false,
-- constraints = {op = "~>", version = {1,0}}}, arch = "rockspec").
-- If the arch field is omitted, the local architecture (cfg.arch)
-- is used. The special value "any" is also recognized, returning all
-- matches regardless of architecture.
local function store_if_match(results, repo, name, version, arch, query)
   if match_name(query, name) then
      if query.arch[arch] or query.arch["any"] then
         if deps.match_constraints(deps.parse_version(version), query.constraints) then
            store_result(results, name, version, arch, repo)
         end
      end
   end
end

--- Perform search on a local repository.
-- @param repo string: The pathname of the local repository.
-- @param query table: A table describing the query in dependency
-- format (for example, {name = "filesystem", exact_name = false,
-- constraints = {op = "~>", version = {1,0}}}, arch = "rockspec").
-- If the arch field is omitted, the local architecture (cfg.arch)
-- is used. The special value "any" is also recognized, returning all
-- matches regardless of architecture.
-- @param results table or nil: If given, this table will store the
-- results; if not given, a new table will be created.
-- @param table: The results table, where keys are package names and
-- versions are tables matching version strings to an array of servers.
-- If a table was given in the "results" parameter, that is the result value.
function disk_search(repo, query, results)
   assert(type(repo) == "string")
   assert(type(query) == "table")
   assert(type(results) == "table" or not results)
   
   local fs = require("luarocks.fs")
     
   if not results then
      results = {}
   end
   query_arch_as_table(query)
   
   for _, name in pairs(fs.list_dir(repo)) do
      local pathname = dir.path(repo, name)
      local rname, rversion, rarch = path.parse_name(name)
      if fs.is_dir(pathname) then
         for _, version in pairs(fs.list_dir(pathname)) do
            if version:match("-%d+$") then
               store_if_match(results, repo, name, version, "installed", query)
            end
         end
      elseif rname then
         store_if_match(results, repo, rname, rversion, rarch, query)
      end
   end
   return results
end

--- Perform search on a rocks server.
-- @param results table: The results table, where keys are package names and
-- versions are tables matching version strings to an array of servers.
-- @param repo string: The URL of the rocks server.
-- @param query table: A table describing the query in dependency
-- format (for example, {name = "filesystem", exact_name = false,
-- constraints = {op = "~>", version = {1,0}}}, arch = "rockspec").
-- If the arch field is omitted, the local architecture (cfg.arch)
-- is used. The special value "any" is also recognized, returning all
-- matches regardless of architecture.
-- @return true or, in case of errors, nil and an error message.
function manifest_search(results, repo, query)
   assert(type(results) == "table")
   assert(type(repo) == "string")
   assert(type(query) == "table")
   
   query_arch_as_table(query)
   local manifest, err = manif.load_manifest(repo)
   if not manifest then
      return nil, "Failed loading manifest: "..err
   end
   for name, versions in pairs(manifest.repository) do
      for version, items in pairs(versions) do
         for _, item in ipairs(items) do
            store_if_match(results, repo, name, version, item.arch, query)
         end
      end
   end
   return true
end

--- Search on all configured rocks servers.
-- @param query table: A dependency query.
-- @return table or (nil, string): A table where keys are package names
-- and values are tables matching version strings to an array of
-- rocks servers; if no results are found, an empty table is returned.
-- In case of errors, nil and and error message are returned.
function search_repos(query)
   assert(type(query) == "table")

   local results = {}
   for _, repo in ipairs(cfg.rocks_servers) do
      local protocol, pathname = dir.split_url(repo)
      if protocol == "file" then
         repo = pathname
      end
      local ok, err = manifest_search(results, repo, query)
      if not ok then
         util.warning("Failed searching manifest: "..err)
      end
   end
   return results
end

--- Prepare a query in dependency table format.
-- @param name string: The query name.
-- @param version string or nil: 
-- @return table: A query in table format
function make_query(name, version)
   assert(type(name) == "string")
   assert(type(version) == "string" or not version)
   
   local query = {
      name = name,
      constraints = {}
   }
   if version then
      table.insert(query.constraints, { op = "==", version = deps.parse_version(version)})
   end
   return query
end

--- Get the URL for the latest in a set of versions.
-- @param name string: The package name to be used in the URL.
-- @param versions table: An array of version informations, as stored
-- in search results tables.
-- @return string or nil: the URL for the latest version if one could
-- be picked, or nil.
local function pick_latest_version(name, versions)
   assert(type(name) == "string")
   assert(type(versions) == "table")

   local vtables = {}
   for v, _ in pairs(versions) do
      table.insert(vtables, deps.parse_version(v))
   end
   table.sort(vtables)
   local version = vtables[#vtables].string
   local items = versions[version]
   if items then
      local pick = 1
      for i, item in ipairs(items) do
         if (item.arch == 'src' and items[pick].arch == 'rockspec')
         or (item.arch ~= 'src' and item.arch ~= 'rockspec') then
            pick = i
         end
      end
      return path.make_url(items[pick].repo, name, version, items[pick].arch)
   end
   return nil
end

--- Attempt to get a single URL for a given search.
-- @param query table: A dependency query.
-- @return string or table or (nil, string): URL for matching rock if
-- a single one was found, a table of candidates if it could not narrow to
-- a single result, or nil followed by an error message.
function find_suitable_rock(query)
   assert(type(query) == "table")
   
   local results, err = search_repos(query)
   if not results then
      return nil, err
   end
   local first = next(results)
   if not first then
      return nil, "No results matching query were found."
   elseif not next(results, first) then
      return pick_latest_version(query.name, results[first])
   else
      return results
   end
end

--- Print a list of rocks/rockspecs on standard output.
-- @param results table: A table where keys are package names and versions
-- are tables matching version strings to an array of rocks servers.
-- @param show_repo boolean or nil: Whether to show repository
-- @param long boolean or nil: Whether to show module files
-- information or not. Default is true.
function print_results(results, show_repo, long)
   assert(type(results) == "table")
   assert(type(show_repo) == "boolean" or not show_repo)
   -- Force display of repo location for the time being
   show_repo = true -- show_repo == nil and true or show_repo
   
   for package, versions in util.sortedpairs(results) do
      util.printout(package)
      for version, repos in util.sortedpairs(versions, deps.compare_versions) do
         if show_repo then
            for _, repo in ipairs(repos) do
               util.printout("   "..version.." ("..repo.arch..") - "..repo.repo)
            end
         else
            util.printout("   "..version)
         end
      end
      util.printout()
   end
end

--- Splits a list of search results into two lists, one for "source" results
-- to be used with the "build" command, and one for "binary" results to be
-- used with the "install" command.
-- @param results table: A search results table.
-- @return (table, table): Two tables, one for source and one for binary
-- results.
local function split_source_and_binary_results(results)
   local sources, binaries = {}, {}
   for name, versions in pairs(results) do
      for version, repos in pairs(versions) do
         for _, repo in ipairs(repos) do
            local where = sources
            if repo.arch == "all" or repo.arch == cfg.arch then
               where = binaries
            end
            store_result(where, name, version, repo.arch, repo.repo)
         end
      end
   end
   return sources, binaries
end

--- Given a name and optionally a version, try to find in the rocks
-- servers a single .src.rock or .rockspec file that satisfies
-- the request, and run the given function on it; or display to the
-- user possibilities if it couldn't narrow down a single match.
-- @param action function: A function that takes a .src.rock or
-- .rockspec URL as a parameter.
-- @param name string: A rock name
-- @param version string or nil: A version number may also be given.
-- @return The result of the action function, or nil and an error message. 
function act_on_src_or_rockspec(action, name, version, ...)
   assert(type(action) == "function")
   assert(type(name) == "string")
   assert(type(version) == "string" or not version)

   local query = make_query(name, version)
   query.arch = "src|rockspec"
   local results, err = find_suitable_rock(query)
   if type(results) == "string" then
      return action(results, ...)
   elseif type(results) == "table" and next(results) then
      util.printout("Multiple search results were returned.")
      util.printout()
      util.printout("Search results:")
      util.printout("---------------")
      print_results(results)
      return nil, "Please narrow your query."
   else
      return nil, "Could not find a result named "..name..(version and " "..version or "").."."
   end
end

--- Driver function for "search" command.
-- @param name string: A substring of a rock name to search.
-- @param version string or nil: a version may also be passed.
-- @return boolean or (nil, string): True if build was successful; nil and an
-- error message otherwise.
function run(...)
   local flags, name, version = util.parse_flags(...)
   
   if flags["all"] then
      name, version = "", nil
   end

   if type(name) ~= "string" and not flags["all"] then
      return nil, "Enter name and version or use --all; see help."
   end
   
   local query = make_query(name:lower(), version)
   query.exact_name = false
   local results, err = search_repos(query)
   if not results then
      return nil, err
   end
   util.printout()
   util.printout("Search results:")
   util.printout("===============")
   util.printout()
   local sources, binaries = split_source_and_binary_results(results)
   if next(sources) and not flags["binary"] then
      util.printout("Rockspecs and source rocks:")
      util.printout("---------------------------")
      util.printout()
      print_results(sources, true)
   end
   if next(binaries) and not flags["source"] then    
      util.printout("Binary and pure-Lua rocks:")
      util.printout("--------------------------")
      util.printout()
      print_results(binaries, true)
   end
   return true
end
