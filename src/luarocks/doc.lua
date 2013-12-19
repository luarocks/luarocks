
--- Module implementing the LuaRocks "doc" command.
-- Shows documentation for an installed rock.
module("luarocks.doc", package.seeall)

local util = require("luarocks.util")
local show = require("luarocks.show")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
--[[
local search = require("luarocks.search")
local cfg = require("luarocks.cfg")
local deps = require("luarocks.deps")
local manif = require("luarocks.manif")
]]
help_summary = "Shows documentation for an installed rock."

help = [[
<argument> is an existing package name.
Without any flags, tries to load the documentation
using a series of heuristics.
With these flags, return only the desired information:

--home      Open the home page of project.

For more information about a rock, see the 'show' command.
]]

--[[
local function keys_as_string(t, sep)
    return table.concat(util.keys(t), sep or " ")
end

local function word_wrap(line) 
   local width = tonumber(os.getenv("COLUMNS")) or 80
   if width > 80 then width = 80 end
   if #line > width then
      local brk = width
      while brk > 0 and line:sub(brk, brk) ~= " " do
         brk = brk - 1
      end
      if brk > 0 then
         return line:sub(1, brk-1) .. "\n" .. word_wrap(line:sub(brk+1))
      end
   end
   return line
end

local function format_text(text)
   text = text:gsub("^%s*",""):gsub("%s$", ""):gsub("\n[ \t]+","\n"):gsub("([^\n])\n([^\n])","%1 %2")
   local paragraphs = util.split_string(text, "\n\n")
   for n, line in ipairs(paragraphs) do
      paragraphs[n] = word_wrap(line)
   end
   return (table.concat(paragraphs, "\n\n"):gsub("%s$", ""))
end

local function module_name(mod, filename, name, version, repo, manifest)
   local base_dir
   if filename:match("%.lua$") then
      base_dir = path.deploy_lua_dir(repo)
   else
      base_dir = path.deploy_lib_dir(repo)
   end
   
   return dir.path(base_dir, filename)
end
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

   if flags["home"] then
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
      if descript.homepage then
         util.printout("Local documentation directory not found -- opening "..descript.homepage.." ...")
         fs.browser(descript.homepage)
         return true
      end
      return nil, "Documentation directory not found for "..name.." "..version
   end

   local files = fs.find(docdir)
   local extensions = { ".html", ".md", ".txt", "" }
   local basenames = { "index", "readme", "manual" }
   
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
            util.printout("Opening "..pathname.." ...")
            if not fs.browser(pathname) then
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

