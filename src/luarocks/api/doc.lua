local doc = {}

local config_api = require("luarocks.api.config")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local download = require("luarocks.download")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local queries = require("luarocks.queries")
local util = require("luarocks.util")
local search = require("luarocks.search")

local function try_to_get_homepage(name, version)
   local temp_dir, err = fs.make_temp_dir("doc-" .. name .. "-" .. (version or ""))
   if not temp_dir then
      return nil, "Failed creating temporary directory: " .. err
   end
   util.schedule_function(fs.delete, temp_dir)

   local ok, err = fs.change_dir(temp_dir)
   if not ok then return nil, err end

   local filename, err = download.download("rockspec", name, version)
   if not filename then return nil, err end

   local rockspec, err = fetch.load_local_rockspec(filename)
   if not rockspec then return nil, err end

   fs.pop_dir()

   local description = rockspec.description or {}
   if not description.homepage then
      return nil, "No homepage defined for " .. name
   end

   return description.homepage
end

function doc.homepage(name, version, tree)
   config_api.set_rock_tree(tree)

   local query = queries.new(name, version)
   local iname, iversion = search.pick_installed_rock(query, tree)
   if not iname then
      return try_to_get_homepage(name, version)
   end
   name, version = iname, iversion

   local rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version, repo))
   if not rockspec then return nil, err end

   local description = rockspec.description or {}
   if not description.homepage then
      return nil, "No 'homepage' field in rockspec for " .. name .. " " .. version
   end

   return description.homepage
end

function doc.doc(name, version, tree)
   config_api.set_rock_tree(tree)

   local query = queries.new(name, version)
   local iname, iversion, repo = search.pick_installed_rock(query, tree)
   if not iname then
      return nil, name .. (version and " " .. version or "") .. " is not installed" 
   end
   name, version = iname, iversion

   local directory = path.install_dir(name, version, repo)

   local docdir
   local directories = { "doc", "docs" }
   for _, d in ipairs(directories) do
      local dirname = dir.path(directory, d)
      if fs.is_dir(dirname) then
         docdir = dirname
         break
      end
   end
   
   if not docdir then
      return nil, "Local documentation directory not found" 
   end

   docdir = dir.normalize(docdir):gsub("/+", "/")
   local files = fs.find(docdir)
   local html_pattern = "%.html?$"
   local extensions = { html_pattern, "%.md$", "%.txt$", "%.textile", "" }
   local basenames = { "index", "readme", "manual" }

   for _, extension in ipairs(extensions) do
      for _, basename in ipairs(basenames) do
         local filename = basename .. extension
         
         local found
         for _, file in ipairs(files) do
            if file:lower():match(filename) and ((not found) or #file < #found) then
               found = file
            end
         end
         if found then
            return docdir, found, files
         end
      end
   end

   return docdir, nil, files 
end

return doc
