
--- Module implementing the luarocks "download" command.
-- Download a rock from the repository.
module("luarocks.download", package.seeall)

local util = require("luarocks.util")
local path = require("luarocks.path")
local fetch = require("luarocks.fetch")
local search = require("luarocks.search")

help_summary = "Download a specific rock file from a rocks server."
help_arguments = "[--all] [--arch=<arch> | --source | --rockspec] [<name> [<version>]]"

help = [[
--all          Download all files if there are multiple matches.
--source       Download .src.rock if available.
--rockspec     Download .rockspec if available.
--arch=<arch>  Download rock for a specific architecture.
]]

function download(arch, name, version, all)
   local results, err
   local query = search.make_query(name, version)
   if arch then query.arch = arch end
   if all then
      if name == "" then query.exact_name = false end
      results, err = search.search_repos(query)
   else
      results, err = search.find_suitable_rock(query)
   end
   if type(results) == "string" then
      local file = fetch.fetch_url(results)
      return file
   elseif type(results) == "table" and next(results) then
      if all then
         local all_ok = true
         local any_err = ""
         for name, result in pairs(results) do
            for version, versions in pairs(result) do
               for _,items in pairs(versions) do
                  local filename = path.make_url(items.repo, name, version, items.arch)
                  local ok, err = fetch.fetch_url(filename)
                  if not ok then
                     all_ok = false
                     any_err = any_err .. "\n" .. err
                  end
               end
            end
         end
         return all_ok, any_err
      else
         util.printerr("Multiple search results were returned.")
         util.printout()
         util.printout("Search results:")
         util.printout("---------------")
         search.print_results(results)
         return nil, "Please narrow your query or use --all."
      end
   end
   return nil, "Could not find a result named "..name..(version and " "..version or "").."."
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

   local arch

   if flags["source"] then
      arch = "src"
   elseif flags["rockspec"] then
      arch = "rockspec"
   elseif flags["arch"] then
      arch = flags["arch"]
   end
   
   local dl, err = download(arch, name, version, flags["all"])
   return dl and true, err
end
