
--- Module implementing the LuaRocks "search" command.
-- Queries LuaRocks servers.
local search = {}
package.loaded["luarocks.search"] = search

local dir = require("luarocks.dir")
local path = require("luarocks.path")
local manif = require("luarocks.manif")
local deps = require("luarocks.deps")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")

util.add_run_function(search)
search.help_summary = "Query the LuaRocks servers."
search.help_arguments = "[--source] [--binary] { <name> [<version>] | --all }"
search.help = [[
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
-- values are tables matching version strings to arrays of
-- tables with fields "arch" and "repo".
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
-- values are tables matching version strings to arrays of
-- tables with fields "arch" and "repo".
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
-- @return table: The results table, where keys are package names and
-- values are tables matching version strings to arrays of
-- tables with fields "arch" and "repo".
-- If a table was given in the "results" parameter, that is the result value.
function search.disk_search(repo, query, results)
   assert(type(repo) == "string")
   assert(type(query) == "table")
   assert(type(results) == "table" or not results)
   
   local fs = require("luarocks.fs")
     
   if not results then
      results = {}
   end
   query_arch_as_table(query)
   
   for name in fs.dir(repo) do
      local pathname = dir.path(repo, name)
      local rname, rversion, rarch = path.parse_name(name)

      if rname and (pathname:match(".rockspec$") or pathname:match(".rock$")) then
         store_if_match(results, repo, rname, rversion, rarch, query)
      elseif fs.is_dir(pathname) then
         for version in fs.dir(pathname) do
            if version:match("-%d+$") then
               store_if_match(results, repo, name, version, "installed", query)
            end
         end
      end
   end
   return results
end

--- Perform search on a rocks server or tree.
-- @param results table: The results table, where keys are package names and
-- values are tables matching version strings to arrays of
-- tables with fields "arch" and "repo".
-- @param repo string: The URL of a rocks server or
-- the pathname of a rocks tree (as returned by path.rocks_dir()).
-- @param query table: A table describing the query in dependency
-- format (for example, {name = "filesystem", exact_name = false,
-- constraints = {op = "~>", version = {1,0}}}, arch = "rockspec").
-- If the arch field is omitted, the local architecture (cfg.arch)
-- is used. The special value "any" is also recognized, returning all
-- matches regardless of architecture.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @return true or, in case of errors, nil, an error message and an optional error code.
function search.manifest_search(results, repo, query, lua_version)
   assert(type(results) == "table")
   assert(type(repo) == "string")
   assert(type(query) == "table")
   
   query_arch_as_table(query)
   local manifest, err, errcode = manif.load_manifest(repo, lua_version)
   if not manifest then
      return nil, err, errcode
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
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @return table: A table where keys are package names
-- and values are tables matching version strings to arrays of
-- tables with fields "arch" and "repo".
function search.search_repos(query, lua_version)
   assert(type(query) == "table")

   local results = {}
   for _, repo in ipairs(cfg.rocks_servers) do
      if not cfg.disabled_servers[repo] then
         if type(repo) == "string" then
            repo = { repo }
         end
         for _, mirror in ipairs(repo) do
            local protocol, pathname = dir.split_url(mirror)
            if protocol == "file" then
               mirror = pathname
            end
            local ok, err, errcode = search.manifest_search(results, mirror, query, lua_version)
            if errcode == "network" then
               cfg.disabled_servers[repo] = true
            end
            if ok then
               break
            else
               util.warning("Failed searching manifest: "..err)
            end
         end
      end
   end
   -- search through rocks in cfg.rocks_provided
   local provided_repo = "provided by VM or rocks_provided"
   for name, versions in pairs(cfg.rocks_provided) do
      store_if_match(results, provided_repo, name, versions, "installed", query)
   end
   return results
end

--- Prepare a query in dependency table format.
-- @param name string: The query name.
-- @param version string or nil: 
-- @return table: A query in table format
function search.make_query(name, version)
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

-- Find out which other Lua versions provide rock versions matching a query,
-- @param query table: A dependency query matching a single rock.
-- @return table: array of Lua versions supported, in "5.x" format.
local function supported_lua_versions(query)
   local results = {}

   for lua_version in util.lua_versions() do
      if lua_version ~= cfg.lua_version then
         if search.search_repos(query, lua_version)[query.name] then
            table.insert(results, lua_version)
         end
      end
   end

   return results
end

--- Attempt to get a single URL for a given search for a rock.
-- @param query table: A dependency query matching a single rock.
-- @return string or (nil, string): URL for latest matching version
-- of the rock if it was found, or nil followed by an error message.
function search.find_suitable_rock(query)
   assert(type(query) == "table")
   
   local results = search.search_repos(query)
   local first_rock = next(results)
   if not first_rock then
      if cfg.rocks_provided[query.name] == nil then
         -- Check if constraints are satisfiable with other Lua versions.
         local lua_versions = supported_lua_versions(query)

         if #lua_versions ~= 0 then
            -- Build a nice message in "only Lua 5.x and 5.y but not 5.z." format
            for i, lua_version in ipairs(lua_versions) do
               lua_versions[i] = "Lua "..lua_version
            end

            local versions_message = "only "..table.concat(lua_versions, " and ")..
               " but not Lua "..cfg.lua_version.."."

            if #query.constraints == 0 then
               return nil, query.name.." supports "..versions_message
            elseif #query.constraints == 1 and query.constraints[1].op == "==" then
               return nil, query.name.." "..query.constraints[1].version.string.." supports "..versions_message
            else
               return nil, "Matching "..query.name.." versions support "..versions_message
            end
         end
      end

      return nil, "No results matching query were found."
   elseif next(results, first_rock) then
      -- Shouldn't happen as query must match only one package.
      return nil, "Several rocks matched query."
   elseif cfg.rocks_provided[query.name] ~= nil then
      -- Do not install versions listed in cfg.rocks_provided.
      return nil, "Rock "..query.name.." "..cfg.rocks_provided[query.name]..
         " was found but it is provided by VM or 'rocks_provided' in the config file."
   else
      return pick_latest_version(query.name, results[first_rock])
   end
end

--- Print a list of rocks/rockspecs on standard output.
-- @param results table: A table where keys are package names and versions
-- are tables matching version strings to an array of rocks servers.
-- @param porcelain boolean or nil: A flag to force machine-friendly output.
function search.print_results(results, porcelain)
   assert(type(results) == "table")
   assert(type(porcelain) == "boolean" or not porcelain)
   
   for package, versions in util.sortedpairs(results) do
      if not porcelain then
         util.printout(package)
      end
      for version, repos in util.sortedpairs(versions, deps.compare_versions) do
         for _, repo in ipairs(repos) do
            repo.repo = dir.normalize(repo.repo)
            if porcelain then
               util.printout(package, version, repo.arch, repo.repo)
            else
               util.printout("   "..version.." ("..repo.arch..") - "..repo.repo)
            end
         end
      end
      if not porcelain then
         util.printout()
      end
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
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
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
function search.act_on_src_or_rockspec(action, name, version, ...)
   assert(type(action) == "function")
   assert(type(name) == "string")
   assert(type(version) == "string" or not version)

   local query = search.make_query(name, version)
   query.arch = "src|rockspec"
   local url, err = search.find_suitable_rock(query)
   if not url then
      return nil, "Could not find a result named "..name..(version and " "..version or "")..": "..err
   end
   return action(url, ...)
end

function search.pick_installed_rock(name, version, given_tree)
   local results = {}
   local query = search.make_query(name, version)
   query.exact_name = true
   local tree_map = {}
   local trees = cfg.rocks_trees
   if given_tree then
      trees = { given_tree }
   end
   for _, tree in ipairs(trees) do
      local rocks_dir = path.rocks_dir(tree)
      tree_map[rocks_dir] = tree
      search.manifest_search(results, rocks_dir, query)
   end

   if not next(results) then --
      return nil,"cannot find package "..name.." "..(version or "").."\nUse 'list' to find installed rocks."
   end

   version = nil
   local repo_url
   local package, versions = util.sortedpairs(results)()
   --question: what do we do about multiple versions? This should
   --give us the latest version on the last repo (which is usually the global one)
   for vs, repositories in util.sortedpairs(versions, deps.compare_versions) do
      if not version then version = vs end
      for _, rp in ipairs(repositories) do repo_url = rp.repo end
   end

   local repo = tree_map[repo_url]
   return name, version, repo, repo_url
end

--- Driver function for "search" command.
-- @param name string: A substring of a rock name to search.
-- @param version string or nil: a version may also be passed.
-- @return boolean or (nil, string): True if build was successful; nil and an
-- error message otherwise.
function search.command(flags, name, version)
   if flags["all"] then
      name, version = "", nil
   end

   if type(name) ~= "string" and not flags["all"] then
      return nil, "Enter name and version or use --all. "..util.see_help("search")
   end
   
   local query = search.make_query(name:lower(), version)
   query.exact_name = false
   local results, err = search.search_repos(query)
   local porcelain = flags["porcelain"]
   util.title("Search results:", porcelain, "=")
   local sources, binaries = split_source_and_binary_results(results)
   if next(sources) and not flags["binary"] then
      util.title("Rockspecs and source rocks:", porcelain)
      search.print_results(sources, porcelain)
   end
   if next(binaries) and not flags["source"] then    
      util.title("Binary and pure-Lua rocks:", porcelain)
      search.print_results(binaries, porcelain)
   end
   return true
end

return search
