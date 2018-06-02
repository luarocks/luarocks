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

local function replace_tree(flags, tree)
   tree = dir.normalize(tree)
   --flags["tree"] = tree
   path.use_tree(tree)
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
function luarocks.doc(name, version)

   --- The following code has been copied from command_line.lua; because without this, an error was poppong up:
   --[[ lua: ...a/vert/api1_sandbox/share/lua/5.2/luarocks/core/path.lua:17: assertion failed!
   stack traceback:
      [C]: in function 'assert'
      ...a/vert/api1_sandbox/share/lua/5.2/luarocks/core/path.lua:17: in function 'rocks_dir'
      ...la/lua/vert/api1_sandbox/share/lua/5.2/luarocks/path.lua:78: in function 'install_dir'
      ...la/lua/vert/api1_sandbox/share/lua/5.2/luarocks/path.lua:230: in function 'configure_paths'
      ...a/lua/vert/api1_sandbox/share/lua/5.2/luarocks/fetch.lua:275: in function 'load_local_rockspec'
      ...la/lua/vert/api1_sandbox/share/lua/5.2/luarocks/init.lua:124: in function 'doc'
      api_testing.lua:29: in main chunk
      [C]: in ?
   --]]
   -- because in path.install_dir, cfg.root_dir is called, which has to be specified, which the code below does.
   if 1 then
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
         local root_dir = fs.absolute_name(flags["tree"])
         replace_tree(flags, root_dir)
      end
   elseif flags["local"] then
      if not cfg.home_tree then
         die("The --local flag is meant for operating in a user's home directory.\n"..
             "You are running as a superuser, which is intended for system-wide operation.\n"..
             "To force using the superuser's home, use --tree explicitly.")
      end
      replace_tree(flags, cfg.home_tree)
   else
      local trees = cfg.rocks_trees
      path.use_tree(trees[#trees])
   end
   
   if type(cfg.root_dir) == "string" then
      cfg.root_dir = cfg.root_dir:gsub("/+$", "")
   else
      cfg.root_dir.root = cfg.root_dir.root:gsub("/+$", "")
   end
   -- command_line.lua copied code ends here

   if not name then
      return nil, "Argument missing. "
   end

   name = name:lower()

   -- for now i can do away with flags["tree"]
   --local iname, iversion, repo = search.pick_installed_rock(name, version, flags["tree"])
   local iname, iversion, repo = search.pick_installed_rock(name, version)
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

return luarocks
