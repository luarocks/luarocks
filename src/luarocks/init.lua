--- LuaRocks public programmatic API, version 3.0
local luarocks = {}

local cfg = require("luarocks.core.cfg")
local search = require("luarocks.search")
local vers = require("luarocks.vers")
local util = require("luarocks.util")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local download = require("luarocks.download")
local manif = require("luarocks.manif")
local repos = require("luarocks.repos")

local function replace_tree(flags, tree)
   tree = dir.normalize(tree)
   path.use_tree(tree)
end

local function set_rock_tree(tree_arg)
   if tree_arg then
      local named = false
      for _, tree in ipairs(cfg.rocks_trees) do
         if type(tree) == "table" then
            if not tree.root then
               die("Configuration error: tree '"..tree.name.."' has no 'root' field.")
            end
            replace_tree(flags, tree.root)
            named = true
            break
         end
      end
      if not named then
         local root_dir = fs.absolute_name(tree_arg)
         replace_tree(flags, root_dir)
      end
   else
      local trees = cfg.rocks_trees
      path.use_tree(trees[#trees])
   end
   
   if type(cfg.root_dir) == "string" then
      cfg.root_dir = cfg.root_dir:gsub("/+$", "")
   else
      cfg.root_dir.root = cfg.root_dir.root:gsub("/+$", "")
   end
end


--- Obtain version of LuaRocks and its API.
-- @return (string, string) Full version of this LuaRocks instance
-- (in "x.y.z" format for releases, or "dev" for a checkout of
-- in-development code), and the API version, in "x.y" format.
function luarocks.version()
   return cfg.program_version, cfg.program_series
end

--- Return 1
function luarocks.test_func()
	return 1
end

--- Return a list of rock-trees
function luarocks.list_rock_trees()
	return cfg.rocks_trees
end

--- Return table of outdated installed rocks
-- called only by list() function
local function check_outdated(trees, query)
   local results_installed = {}
   for _, tree in ipairs(trees) do
      search.manifest_search(results_installed, path.rocks_dir(tree), query)
   end
   local outdated = {}
   for name, versions in util.sortedpairs(results_installed) do
      versions = util.keys(versions)
      table.sort(versions, vers.compare_versions)
      local latest_installed = versions[1]

      local query_available = search.make_query(name:lower())
      query.exact_name = true
      local results_available, err = search.search_repos(query_available)
      
      if results_available[name] then
         local available_versions = util.keys(results_available[name])
         table.sort(available_versions, vers.compare_versions)
         local latest_available = available_versions[1]
         local latest_available_repo = results_available[name][latest_available][1].repo
         
         if vers.compare_versions(latest_available, latest_installed) then
            table.insert(outdated, { name = name, installed = latest_installed, available = latest_available, repo = latest_available_repo })
         end
      end
   end
   return outdated
end

--- Return a table of installed rocks
function luarocks.list(filter, outdated, version, tree)
   local query = search.make_query(filter and filter:lower() or "", version)
   query.exact_name = false
   local trees = cfg.rocks_trees
   if tree then
     trees = { tree }
   end
   
   if outdated then
      return check_outdated(trees, query)
   end
   
   local results = {}
   for _, tree in ipairs(trees) do
     local ok, err, errcode = search.manifest_search(results, path.rocks_dir(tree), query)
     if not ok and errcode ~= "open" then
        return {err, errcode}
     end
   end
   results = search.return_results(results)
   return results
end


local function try_to_get_homepage(name, version)
   local temp_dir, err = fs.make_temp_dir("doc-"..name.."-"..(version or ""))
   if not temp_dir then
      return nil, "Failed creating temporary directory: "..err
   end
   util.schedule_function(fs.delete, temp_dir)
   local ok, err = fs.change_dir(temp_dir)
   if not ok then return nil, err end
   local filename, err = download.download("rockspec", name, version)
   if not filename then return nil, err end
   local rockspec, err = fetch.load_local_rockspec(filename)
   if not rockspec then return nil, err end
   fs.pop_dir()
   local descript = rockspec.description or {}
   if not descript.homepage then return nil, "No homepage defined for "..name end
   return descript.homepage, nil, nil
end

--- Return homepage and doc file names of an installed rock
function luarocks.doc(name, version, tree)

   set_rock_tree(tree)

   if not name then
      return nil, "Argument missing. "
   end

   name = name:lower()

   local iname, iversion, repo = search.pick_installed_rock(name, version, tree)
   if not iname then
      return try_to_get_homepage(name, version)
   end

   name, version = iname, iversion
   
   local rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version, repo))
   if not rockspec then return nil,err end
   local descript = rockspec.description or {}

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

   docdir = dir.normalize(docdir):gsub("/+", "/")
   local files = fs.find(docdir)
   local htmlpatt = "%.html?$"
   local extensions = { htmlpatt, "%.md$", "%.txt$",  "%.textile$", "" }
   local basenames = { "index", "readme", "manual" }
   
   return descript.homepage, docdir, files
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

local function installed_rock_label(name, tree)
   local installed, version
   if cfg.rocks_provided[name] then
      installed, version = true, cfg.rocks_provided[name]
   else
      installed, version = search.pick_installed_rock(name, nil, tree)
   end
   return installed and "(using "..version..")" or "(missing)"
end

local function return_items_table(name, version, item_set, item_type, repo)
   local return_table = {}
   for item_name in util.sortedpairs(item_set) do
      --util.printout("\t"..item_name.." ("..repos.which(name, version, item_type, item_name, repo)..")")
      table.insert(return_table, {item_name, repos.which(name, version, item_type, item_name, repo)})
   end
   return return_table
end

function luarocks.show(name, version, tree)

   set_rock_tree(tree)
   
   if not name then
      return nil, "Argument missing. "..util.see_help("show")
   end
   
   local repo, repo_url

   name, version, repo, repo_url = search.pick_installed_rock(name:lower(), version, tree)
   if not name then
      return nil, version
   end

   local directory = path.install_dir(name,version,repo)
   local rockspec_file = path.rockspec_file(name, version, repo)
   local rockspec, err = fetch.load_local_rockspec(rockspec_file)
   if not rockspec then
      return nil,err
   end

   local descript = rockspec.description or {}
   local manifest, err = manif.load_manifest(repo_url)
   if not manifest then
      return nil,err
   end
   local minfo = manifest.repository[name][version][1]

   local show_table = {}

   show_table["package"] = rockspec.package
   show_table["version"] = rockspec.version
   show_table["summary"] = rockspec.summary
   if descript.detailed then
      show_table["detailed"] = format_text(descript.detailed)
   end
   if descript.license then
      show_table["license"] = descript.license
   end
   if descript.homepage then
      show_table["homepage"] = descript.homepage
   end
   if descript.issues_url then
      show_table["issues"] = descript.issues
   end
   if descript.labels then
      show_table["labels"] = descript.labels
   end
   show_table["install_loc"] = path.rocks_tree_to_string(repo)

   if next(minfo.commands) then
      show_table["commands"] = return_items_table(name, version, minfo.commands, "command", repo)
   end

   if next(minfo.modules) then
      show_table["modules"] = return_items_table(name, version, minfo.modules, "module", repo)
   end
   
   show_table["deps"] = {}
   local direct_deps = {}
   if #rockspec.dependencies > 0 then
      for _, dep in ipairs(rockspec.dependencies) do
         direct_deps[dep.name] = true
         table.insert(show_table["deps"], {vers.show_dep(dep), installed_rock_label(dep.name, tree)})
      end
   end
   show_table["in_deps"] = {}
   local has_indirect_deps
   for dep_name in util.sortedpairs(minfo.dependencies or {}) do
      if not direct_deps[dep_name] then
         if not has_indirect_deps then
            util.printout()
            util.printout("Indirectly pulling:")
            has_indirect_deps = true
         end
         table.insert(show_table["in_deps"], {dep_name, installed_rock_label(dep_name, tree)})
      end
   end
   return show_table
end

--- Splits a list of search results into two lists, one for "source" results
-- to be used with the "build" command, and one for "binary" results to be
-- used with the "install" command.
-- @param results table: A search results table.
-- @return (table, table): Two tables, one for source and one for binary
-- results.
local function split_source_and_binary_results(results)
   local sources, binaries = {}, {}
   for name, versions in pairs(results) do
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            local where = sources
            if repo.arch == "all" or repo.arch == cfg.arch then
               where = binaries
            end
            search.store_result(where, name, version, repo.arch, repo.repo)
         end
      end
   end
   return sources, binaries
end

--- Return a table of queried rocks from LuaRocks servers
function luarocks.search(name, version, binary_or_source)
   local search_table = {}

   if not name then
      name, version = "", nil
   end

   local query = search.make_query(name:lower(), version)
   query.exact_name = false
   local results, err = search.search_repos(query)
   local sources, binaries = split_source_and_binary_results(results)
   if binary_or_source == nil then
   	  search_table["sources"] = sources
   	  search_table["binary"] =  binary
   elseif next(sources) and (binary_or_source == "source") then
      search_table["sources"] = sources
   elseif next(binaries) and (binary_or_source == "binary") then
      search_table["binary"] =  binary
   end
   return search_table
end

return luarocks
