
--- Module implementing the LuaRocks "doc" command.
-- Shows documentation for an installed rock.
module("luarocks.doc", package.seeall)

local util = require("luarocks.util")
local show = require("luarocks.show")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")

help_summary = "Shows documentation for an installed rock."

help = [[
<argument> is an existing package name.
Without any flags, tries to load the documentation
using a series of heuristics.
With these flags, return only the desired information:

--homepage  Open the home page of project.
--list      List documentation files only.

For more information about a rock, see the 'show' command.
]]

--- Driver function for "doc" command.
-- @param name or nil: an existing package name.
-- @param version string or nil: a version may also be passed.
-- @return boolean: True if succeeded, nil on errors.
function run(...)
   local flags, name, version = util.parse_flags(...)
   if not name then
      return nil, "Argument missing. "..util.see_help("doc")
   end

   local repo
   name, version, repo = show.pick_installed_rock(name, version, flags["tree"])
   if not name then
      return nil, version
   end
   
   local rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version, repo))
   if not rockspec then return nil,err end
   local descript = rockspec.description or {}

   if flags["homepage"] then
      if not descript.homepage then
         return nil, "No 'homepage' field in rockspec for "..name.." "..version
      end
      util.printout("Opening "..descript.homepage.." ...")
      fs.browser(descript.homepage)
      return true
   end

   local directory = path.install_dir(name,version,repo)
   
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
      if descript.homepage and not flags["list"] then
         util.printout("Local documentation directory not found -- opening "..descript.homepage.." ...")
         fs.browser(descript.homepage)
         return true
      end
      return nil, "Documentation directory not found for "..name.." "..version
   end

   docdir = dir.normalize(docdir):gsub("/+", "/")
   local files = fs.find(docdir)
   local htmlpatt = "%.html?$"
   local extensions = { htmlpatt, "%.md$", "%.txt$",  "%.textile$", "" }
   local basenames = { "index", "readme", "manual" }
   
   local porcelain = flags["porcelain"]
   if #files > 0 then
      util.title("Documentation files for "..name.." "..version, porcelain)
      if porcelain then
         for _, file in ipairs(files) do
            util.printout(docdir.."/"..file)
         end
      else
         util.printout(docdir.."/")
         for _, file in ipairs(files) do
            util.printout("\t"..file)
         end
      end
   end
   
   if flags["list"] then
      return true
   end
   
   for _, extension in ipairs(extensions) do
      for _, basename in ipairs(basenames) do
         local filename = basename..extension
         local found
         for _, file in ipairs(files) do
            if file:lower():match(filename) and ((not found) or #file < #found) then
               found = file
            end
         end
         if found then
            local pathname = dir.path(docdir, found)
            util.printout()
            util.printout("Opening "..pathname.." ...")
            util.printout()
            local ok = fs.browser(pathname)
            if not ok and not pathname:match(htmlpatt) then
               local fd = io.open(pathname, "r")
               util.printout(fd:read("*a"))
               fd:close()
            end
            return true
         end
      end
   end

   return true
end

