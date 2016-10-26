
--- Module implementing the luarocks "download" command.
-- Download a rock from the repository.
local download = {}
package.loaded["luarocks.download"] = download

local util = require("luarocks.util")
local path = require("luarocks.path")
local fetch = require("luarocks.fetch")
local search = require("luarocks.search")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

util.add_run_function(download)
download.help_summary = "Download a specific rock file from a rocks server."
download.help_arguments = "[--all] [--arch=<arch> | --source | --rockspec] [<name> [<version>]]"

download.help = [[
--all          Download all files if there are multiple matches.
--source       Download .src.rock if available.
--rockspec     Download .rockspec if available.
--arch=<arch>  Download rock for a specific architecture.
]]

local function get_file(filename)
   local protocol, pathname = dir.split_url(filename)
   if protocol == "file" then
      local ok, err = fs.copy(pathname, fs.current_dir(), cfg.perm_read)
      if ok then
         return pathname
      else
         return nil, err
      end
   else
      return fetch.fetch_url(filename)
   end
end

function download.download(arch, name, version, all)
   local query = search.make_query(name, version)
   if arch then query.arch = arch end
   local search_err

   if all then
      if name == "" then query.exact_name = false end
      local results = search.search_repos(query)
      local has_result = false
      local all_ok = true
      local any_err = ""
      for name, result in pairs(results) do
         for version, items in pairs(result) do
            for _, item in ipairs(items) do
               -- Ignore provided rocks.
               if item.arch ~= "installed" then
                  has_result = true
                  local filename = path.make_url(item.repo, name, version, item.arch)
                  local ok, err = get_file(filename)
                  if not ok then
                     all_ok = false
                     any_err = any_err .. "\n" .. err
                  end
               end
            end
         end
      end

      if has_result then
         return all_ok, any_err
      end
   else
      local url
      url, search_err = search.find_suitable_rock(query)
      if url then
         return get_file(url)
      end
   end
   return nil, "Could not find a result named "..name..(version and " "..version or "")..
      (search_err and ": "..search_err or ".")
end

--- Driver function for the "download" command.
-- @param name string: a rock name.
-- @param version string or nil: if the name of a package is given, a
-- version may also be passed.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
function download.command(flags, name, version)
   assert(type(version) == "string" or not version)
   if type(name) ~= "string" and not flags["all"] then
      return nil, "Argument missing. "..util.see_help("download")
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
   
   local dl, err = download.download(arch, name:lower(), version, flags["all"])
   return dl and true, err
end

return download
