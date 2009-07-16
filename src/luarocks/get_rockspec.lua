
--- Module implementing the luarocks "get_rockspec" command.
-- Download a rockspec from the repository.
module("luarocks.get_rockspec", package.seeall)

local util = require("luarocks.util")
local path = require("luarocks.path")
local fetch = require("luarocks.fetch")
local search = require("luarocks.search")

help_summary = "Download a specific rockspec file from a rocks server."
help_arguments = "[--all] [<name> [<version>]]"

help = [[
--all     Download multiple rockspec files if there is more than one match.
]]

local function get_rockspec(rockspec_file)
   local rockspec = fetch.load_rockspec(rockspec_file, ".")
   if not rockspec then
      return nil, "Failed loading rockspec "..rockspec_file
   end
   return true
end

--- Driver function for the "get_rockspec" command.
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
   query.arch = "rockspec"
   local results, err
   if flags["all"] then
      if name == "" then query.exact_name = false end
      results, err = search.search_repos(query)
      print(results, err)
   else
      results, err = search.find_suitable_rock(query)
   end
   if type(results) == "string" then
      return get_rockspec(results)
   elseif type(results) == "table" and next(results) then
      if flags["all"] then
         local all_ok = true
         local any_err = ""
         for name, result in pairs(results) do
            for version, versions in pairs(result) do
               for _,items in pairs(versions) do
                  local filename = path.make_url(items.repo, name, version, items.arch)
                  local ok, err = get_rockspec(filename)
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
         print_results(results)
         return nil, "Please narrow your query or use --all."
      end
   else
      return nil, "Could not find a result named "..name.."."
   end
end
