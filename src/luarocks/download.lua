
--- Module implementing the luarocks "download" command.
-- Download a rock from the repository.
module("luarocks.download", package.seeall)

local util = require("luarocks.util")
local path = require("luarocks.path")
local fetch = require("luarocks.fetch")
local search = require("luarocks.search")

help_summary = "Download a specific rock file from a rocks server."
help_arguments = "[--all] [--source] [--arch=<arch>] [<name> [<version>]]"

help = [[
--all          Download multiple rock files if there is more than one match.
--source       Download .src.rock if available.
--arch=<arch>  Download rock for a specific architecture.
]]

local function download(rock_file)
   local rock = fetch.fetch_url(rock_file)
   return rock ~= nil
end

--- Driver function for the "download" command.
-- @param name string: a rock name.
-- @param version string or nil: if the name of a package is given, a
-- version may also be passed.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
function run(...)
   local flags, name, version = util.parse_flags(...)

   assert(type(version) == "string" or not version)
   if type(name) ~= "string" and not flags["all"] then
      return nil, "Argument missing, see help."
   end
   if not name then name, version = "", "" end

   local query = search.make_query(name, version)
   if flags["source"] then
      query.arch = "src"
   elseif flags["rockspec"] then
      query.arch = "rockspec"
   elseif flags["arch"] then
      query.arch = flags["arch"]
   end
   local results, err
   if flags["all"] then
      if name == "" then query.exact_name = false end
      results, err = search.search_repos(query)
   else
      results, err = search.find_suitable_rock(query)
   end
   if type(results) == "string" then
      return download(results)
   elseif type(results) == "table" and next(results) then
      if flags["all"] then
         local all_ok = true
         local any_err = ""
         for name, result in pairs(results) do
            for version, versions in pairs(result) do
               for _,items in pairs(versions) do
                  local filename = path.make_url(items.repo, name, version, items.arch)
                  local ok, err = download(filename)
                  if not ok then
                     all_ok = false
                     any_err = any_err .. "\n" .. err
                  end
               end
            end
         end
         return all_ok, any_err
      else
         print("Multiple search results were returned.")
         print()
         print("Search results:")
         print("---------------")
         search.print_results(results)
         return nil, "Please narrow your query or use --all."
      end
   else
      return nil, "Could not find a result named "..name..(version and " "..version or "").."."
   end
end
