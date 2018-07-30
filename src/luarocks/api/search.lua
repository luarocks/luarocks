local search_api = {}

local cfg = require("luarocks.core.cfg")
local queries = require("luarocks.queries")
local results = require("luarocks.results")
local search = require("luarocks.search")

--- Splits a list of search results into two lists, one for "source" results
-- to be used with the "build" command, and one for "binary" results to be
-- used with the "install" command.
-- @param result_tree table: A search results table.
-- @return (table, table): Two tables, one for source and one for binary
-- results.
local function split_source_and_binary_results(result_tree)
   local sources, binaries = {}, {}
   for name, versions in pairs(result_tree) do
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            local where = sources
            if repo.arch == "all" or repo.arch == cfg.arch then
               where = binaries
            end
            local entry = results.new(name, version, repo.repo, repo.arch)
            search.store_result(where, entry)
         end
      end
   end
   return sources, binaries
end

function search_api.search(name, version, binary_or_source)
   local search_table = {}

   if not name then
      name, version = "", nil
   end

   local query = queries.new(name:lower(), version, true)
   local result_tree, err = search.search_repos(query)
   if not result_tree then return nil, err end

   local sources, binaries = split_source_and_binary_results(result_tree)
   if not binary_or_source then
      search_table["sources"] = sources
      search_table["binary"] = binaries
   elseif next(sources) and binary_or_source == "source" then
      search_table["sources"] = sources
   elseif next(binaries) and binary_or_source == "binary" then
      search_table["binary"] = binaries
   end

   return search_table
end

return search_api
