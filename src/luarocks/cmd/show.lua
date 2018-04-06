--- Module implementing the LuaRocks "show" command.
-- Shows information about an installed rock.
local show = {}

local queries = require("luarocks.queries")
local search = require("luarocks.search")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")
local vers = require("luarocks.core.vers")
local fetch = require("luarocks.fetch")
local manif = require("luarocks.manif")
local repos = require("luarocks.repos")

show.help_summary = "Show information about an installed rock."

show.help = [[
<argument> is an existing package name.
Without any flags, show all module information.
With these flags, return only the desired information:

--home      home page of project
--modules   all modules provided by this package as used by require()
--deps      packages this package depends on
--rockspec  the full path of the rockspec file
--mversion  the package version
--rock-tree local tree where rock is installed
--rock-dir  data directory of the installed rock
]]

local function keys_as_string(t, sep)
   local keys = util.keys(t)
   table.sort(keys)
   return table.concat(keys, sep or " ")
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

local function installed_rock_label(dep, tree)
   local installed, version
   if cfg.rocks_provided[dep.name] then
      installed, version = true, cfg.rocks_provided[dep.name]
   else
      installed, version = search.pick_installed_rock(dep, tree)
   end
   return installed and "(using "..version..")" or "(missing)"
end

local function print_items(name, version, item_set, item_type, repo)
   for item_name in util.sortedpairs(item_set) do
      util.printout("\t"..item_name.." ("..repos.which(name, version, item_type, item_name, repo)..")")
   end
end

--- Driver function for "show" command.
-- @param name or nil: an existing package name.
-- @param version string or nil: a version may also be passed.
-- @return boolean: True if succeeded, nil on errors.
function show.command(flags, name, version)
   if not name then
      return nil, "Argument missing. "..util.see_help("show")
   end

   name = util.adjust_name_and_namespace(name, flags)
   local query = queries.new(name, version)
   
   local repo, repo_url
   name, version, repo, repo_url = search.pick_installed_rock(query, flags["tree"])
   if not name then
      return nil, version
   end

   local directory = path.install_dir(name, version, repo)
   local rockspec_file = path.rockspec_file(name, version, repo)
   local rockspec, err = fetch.load_local_rockspec(rockspec_file)
   if not rockspec then return nil,err end

   local descript = rockspec.description or {}
   local manifest, err = manif.load_manifest(repo_url)
   if not manifest then return nil,err end
   local minfo = manifest.repository[name][version][1]

   if flags["rock-tree"] then util.printout(path.rocks_tree_to_string(repo))
   elseif flags["rock-dir"] then util.printout(directory)
   elseif flags["home"] then util.printout(descript.homepage)
   elseif flags["issues"] then util.printout(descript.issues_url)
   elseif flags["labels"] then util.printout(descript.labels and table.concat(descript.labels, "\n"))
   elseif flags["modules"] then util.printout(keys_as_string(minfo.modules, "\n"))
   elseif flags["deps"] then
      for _, dep in ipairs(rockspec.dependencies) do
         util.printout(tostring(dep))
      end
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
      if descript.issues_url then
         util.printout("Issues: ", descript.issues_url)
      end
      if descript.labels then
         util.printout("Labels: ", table.concat(descript.labels, ", "))
      end
      util.printout("Installed in: ", path.rocks_tree_to_string(repo))

      if next(minfo.commands) then
         util.printout()
         util.printout("Commands: ")
         print_items(name, version, minfo.commands, "command", repo)
      end

      if next(minfo.modules) then
         util.printout()
         util.printout("Modules: ")
         print_items(name, version, minfo.modules, "module", repo)
      end

      local direct_deps = {}
      if #rockspec.dependencies > 0 then
         util.printout()
         util.printout("Depends on:")
         for _, dep in ipairs(rockspec.dependencies) do
            direct_deps[dep.name] = true
            util.printout("\t"..tostring(dep).." "..installed_rock_label(dep, flags["tree"]))
         end
      end
      local has_indirect_deps
      for dep_name in util.sortedpairs(minfo.dependencies or {}) do
         if not direct_deps[dep_name] then
            if not has_indirect_deps then
               util.printout()
               util.printout("Indirectly pulling:")
               has_indirect_deps = true
            end

            util.printout("\t"..dep_name.." "..installed_rock_label(dep_name, flags["tree"]))
         end
      end
      util.printout()
   end
   return true
end


return show
