
--- Module implementing the LuaRocks "show" command.
-- Shows information about an installed rock.
module("luarocks.show", package.seeall)

local search = require("luarocks.search")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")
local fetch = require("luarocks.fetch")
local manif = require("luarocks.manif")
help_summary = "Shows information about an installed rock."

help = [[
<argument> is an existing package name.
Without any flags, show all module information.
With these flags, return only the desired information:

--home      home page of project
--modules   all modules provided by this package as used by require()
--deps      packages this package depends on
--rockspec  the full path of the rockspec file
--mversion  the package version
--tree      local tree where rock is installed
--rock-dir  data directory of the installed rock
]]

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

--- Driver function for "show" command.
-- @param name or nil: an existing package name.
-- @param version string or nil: a version may also be passed.
-- @return boolean: True if succeeded, nil on errors.
function run(...)
   local flags, name, version = util.parse_flags(...)
   if not name then
      return nil, "Argument missing, see help."
   end
   local results = {}
   local query = search.make_query(name, version)
   query.exact_name = true
   local tree_map = {}
   for _, tree in ipairs(cfg.rocks_trees) do
      local rocks_dir = path.rocks_dir(tree)
      tree_map[rocks_dir] = tree
      search.manifest_search(results, rocks_dir, query)
   end

   if not next(results) then --
      return nil,"cannot find package "..name.."\nUse 'list' to find installed rocks"
   end

   local version,repo_url
   local package, versions = util.sortedpairs(results)()
   --question: what do we do about multiple versions? This should
   --give us the latest version on the last repo (which is usually the global one)
   for vs, repos in util.sortedpairs(versions, deps.compare_versions) do
      if not version then version = vs end
      for _, rp in ipairs(repos) do repo_url = rp.repo end
   end


   local repo = tree_map[repo_url]
   local directory = path.install_dir(name,version,repo)
   local rockspec_file = path.rockspec_file(name, version, repo)
   local rockspec, err = fetch.load_local_rockspec(rockspec_file)
   if not rockspec then return nil,err end

   local descript = rockspec.description or {}
   local manifest, err = manif.load_manifest(repo_url)
   if not manifest then return nil,err end
   local minfo = manifest.repository[name][version][1]

   if flags["tree"] then util.printout(repo)
   elseif flags["rock-dir"] then util.printout(directory)
   elseif flags["home"] then util.printout(descript.homepage)
   elseif flags["modules"] then util.printout(keys_as_string(minfo.modules))
   elseif flags["deps"] then util.printout(keys_as_string(minfo.dependencies))
   elseif flags["rockspec"] then util.printout(rockspec_file)
   elseif flags["mversion"] then util.printout(version)
   else
      util.printout()
      util.printout(rockspec.package.." "..rockspec.version.." - "..(descript.summary or ""))
      util.printout()
      if descript.detailed then
         util.printout(format_text(descript.detailed))
         util.printout()
      end
      if descript.license then
         util.printout("License: ", descript.license)
      end
      if descript.homepage then
         util.printout("Homepage: ", descript.homepage)
      end
      util.printout("Installed in: ", repo)
      if next(minfo.modules) then
         util.printout()
         util.printout("Modules:")
         util.printout("\t"..keys_as_string(minfo.modules, "\n\t"))
      end
      if next(minfo.dependencies) then
         util.printout()
         util.printout("Depends on:")
         util.printout("\t"..keys_as_string(minfo.dependencies, "\n\t"))
      end
      util.printout()
   end
   return true
end

