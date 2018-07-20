--- LuaRocks public programmatic API, version 3.0
local luarocks = {}

local cfg = require("luarocks.core.cfg")
local queries = require("luarocks.queries")
local search = require("luarocks.search")
local vers = require("luarocks.core.vers")
local util = require("luarocks.util")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local download = require("luarocks.download")
local manif = require("luarocks.manif")
local repos = require("luarocks.repos")
local results = require("luarocks.results")
local remove = require("luarocks.remove")
local deps = require("luarocks.deps")
local writer = require("luarocks.manif.writer")
local cmd = require("luarocks.cmd")
local rockspecs = require("luarocks.rockspecs")
local builtin = require("luarocks.build.builtin")
local persist = require("luarocks.persist")
local type_rockspec = require("luarocks.type.rockspec")
local build = require("luarocks.build")

cfg.init()

local function replace_tree(flags, tree)
   tree = dir.normalize(tree)
   path.use_tree(tree)
end

local function set_rock_tree(tree_arg)
   if tree_arg then
      local named = false
      for _, tree in ipairs(cfg.rocks_trees) do
         if type(tree) == "table" and tree_arg == tree.name then
            if not tree.root then
               die("Configuration error: tree '"..tree.name.."' has no 'root' field.")
            end
            replace_tree(flags, tree.root)
            named = true
            break
         end
      end
      if not named then
         fs.init()
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
      search.local_manifest_search(results_installed, path.rocks_dir(tree), query)
   end
   local outdated = {}
   for name, versions in util.sortedpairs(results_installed) do
      versions = util.keys(versions)
      table.sort(versions, vers.compare_versions)
      local latest_installed = versions[1]

      local query_available = queries.new(name:lower())
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

   set_rock_tree(tree)

   local query = queries.new(filter and filter:lower() or "", version, true)
   local trees = cfg.rocks_trees
   if tree then
     trees = { tree }
   end
   
   if outdated then
      return check_outdated(trees, query)
   end
   
   local results = {}
   for _, tree in ipairs(trees) do
     local ok, err, errcode = search.local_manifest_search(results, path.rocks_dir(tree), query)
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

   --name = util.adjust_name_and_namespace(name, flags)
   local query = queries.new(name, version)
   local iname, iversion, repo = search.pick_installed_rock(query, tree)
   if not iname then
      return try_to_get_homepage(name, version)
   end

   name, version = iname, iversion
   
   local rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version, repo))
   if not rockspec then return nil,err end
   local descript = rockspec.description or {}

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
      if descript.homepage then
         return descript.homepage, "Documentation directory not found for "..name.." "..version
      end
      return nil, "Documentation directory not found for "..name.." "..version
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
   
   --name = util.adjust_name_and_namespace(name, flags)
   local query = queries.new(name, version)
   
   local repo, repo_url
   name, version, repo, repo_url = search.pick_installed_rock(query, tree)
   if not name then
      return nil, version
   end
   local tree = path.rocks_tree_to_string(repo)
   local directory = path.install_dir(name, version, repo)
   local namespace = path.read_namespace(name, version, tree)
   local rockspec_file = path.rockspec_file(name, version, repo)
   local rockspec, err = fetch.load_local_rockspec(rockspec_file)
   if not rockspec then return nil,err end

   local descript = rockspec.description or {}
   local manifest, err = manif.load_manifest(repo_url)
   if not manifest then return nil,err end
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
   if descript.issues_url then
      show_table["issues"] = descript.issues_url
   end
   show_table["install_loc"] = path.rocks_tree_to_string(repo)

   if next(minfo.commands) then
      show_table["commands"] = return_items_table(name, version, minfo.commands, "command", repo)
   end

   if next(minfo.modules) then
      show_table["modules"] = return_items_table(name, version, minfo.modules, "module", repo)
   end

   show_table["deps"] = {}
   if rockspec.dependencies then
      for _, dep in ipairs(rockspec.dependencies) do
         table.insert(show_table["deps"], tostring(dep))
      end
   end
   show_table["test-deps"] = {}
   if rockspec.build_dependencies then
      for _, dep in ipairs(rockspec.build_dependencies) do
         table.insert(show_table["test-deps"], tostring(dep))
      end
   end
   show_table["build-deps"] = {}
   if rockspec.test_dependencies then
      for _, dep in ipairs(rockspec.test_dependencies) do
         table.insert(show_table["build-deps"], tostring(dep))
      end
   end
   return show_table
end

--- Splits a list of search results into two lists, one for "source" results
-- to be used with the "build" command, and one for "binary" results to be
-- used with the "install" command.
-- @param result_tree table: A search results table.
-- @return (table, table): Two tables, one for source and one for binary
-- results.
local function split_source_and_binary_results(result_tree)
   local sources, binaries = {}, {}
   for name, versions in pairs(result_tree) do
      for version, repositories in pairs(versions) do
         for _, repo in ipairs(repositories) do
            local where = sources
            if repo.arch == "all" or repo.arch == cfg.arch then
               where = binaries
            end
            local entry = results.new(name, version, repo.repo, repo.arch)
            search.store_result(where, entry)
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

   local query = queries.new(name:lower(), version, true)
   local result_tree, err = search.search_repos(query)
   local sources, binaries = split_source_and_binary_results(result_tree)
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

--- force = nil for not forcing
-- "force" for force
-- "force-fast" for fast-force
function luarocks.remove(name, version, tree, force)

   set_rock_tree(tree)

   fs.init()

   if type(name) ~= "string" then
      return nil, "Argument missing. "
   end
   
   --local deps_mode = flags["deps-mode"] or cfg.deps_mode
   deps_mode = cfg.deps_mode
   --

   --local ok, err = fs.check_command_permissions_no_flags(flags)
   local ok, err = fs.check_command_permissions_no_flags()
   --
   if not ok then return nil, err, cmd.errorcodes.PERMISSIONDENIED end
   
   local rock_type = name:match("%.(rock)$") or name:match("%.(rockspec)$")
   local filename = name
   if rock_type then
      name, version = path.parse_name(filename)
      if not name then return nil, "Invalid "..rock_type.." filename: "..filename end
   end

   local results = {}
   name = name:lower()
   search.local_manifest_search(results, cfg.rocks_dir, queries.new(name, version))
   if not results[name] then
      return nil, "Could not find rock '"..name..(version and " "..version or "").."' in "..path.rocks_tree_to_string(cfg.root_dir)
   end

   --local ok, err = remove.remove_search_results(results, name, deps_mode, flags["force"], flags["force-fast"])
   local ok, err = nil, nil
   if force == "force" then
      ok, err = remove.remove_search_results_return(results, name, deps_mode, true, false)
   elseif force == "force-fast" then
      ok, err = remove.remove_search_results_return(results, name, deps_mode, false, true)
   else
      ok, err = remove.remove_search_results_return(results, name, deps_mode, false, false)
   end
   --

   if not ok then
      return ok, err
   end

   --writer.check_dependencies(nil, deps.get_deps_mode(flags))
   --

   return true, err
end

function luarocks.lint(input, tree)

   -- Even though this function doesn't necessarily require a tree argument, it needs to calll this function to not break - fetch.load_local_rockspec()
   set_rock_tree(tree)

   if not input then
      return nil, "Argument missing. "
   end
   
   local filename = input
   if not input:match(".rockspec$") then
      local err
      filename, err = download.download("rockspec", input:lower())
      if not filename then
         return nil, err
      end
   end

   local rs, err = fetch.load_local_rockspec(filename)
   if not rs then
      return nil, "Failed loading rockspec: "..err
   end

   local ok = true
   
   -- This should have been done in the type checker, 
   -- but it would break compatibility of other commands.
   -- Making 'lint' alone be stricter shouldn't be a problem,
   -- because extra-strict checks is what lint-type commands
   -- are all about.
   if not rs.description.license then
      util.printerr("Rockspec has no license field.")
      ok = false
   end

   return ok, ok or filename.." failed consistency checks."
end

local function open_file(name)
   return io.open(dir.path(fs.current_dir(), name), "r")
end

local function fetch_url(rockspec)
   local file, temp_dir, err_code, err_file, err_temp_dir = fetch.fetch_sources(rockspec, false)
   if err_code == "source.dir" then
      file, temp_dir = err_file, err_temp_dir
   elseif not file then
      return false, "Could not fetch sources - "..temp_dir
   end
   if dir.is_basic_protocol(rockspec.source.protocol) then
      rockspec.source.md5 = fs.get_md5(file)
   end
   local inferred_dir, found_dir = fetch.find_base_dir(file, temp_dir, rockspec.source.url)
   return true, found_dir or inferred_dir, temp_dir
end

local lua_version_dep = {
   ["5.1"] = "lua ~> 5.1",
   ["5.2"] = "lua ~> 5.2",
   ["5.3"] = "lua ~> 5.3",
   ["5.4"] = "lua ~> 5.4",
   ["5.1,5.2"] = "lua >= 5.1, < 5.3",
   ["5.2,5.3"] = "lua >= 5.2, < 5.4",
   ["5.3,5.4"] = "lua >= 5.3, < 5.5",
   ["5.1,5.2,5.3"] = "lua >= 5.1, < 5.4",
   ["5.2,5.3,5.4"] = "lua >= 5.2, < 5.5",
   ["5.1,5.2,5.3,5.4"] = "lua >= 5.1, < 5.5",
}

local simple_scm_protocols = {
   git = true, ["git+http"] = true, ["git+https"] = true,
   hg = true, ["hg+http"] = true, ["hg+https"] = true
}

local detect_url
do
   local function detect_url_from_command(program, args, directory)
      local command = fs.Q(cfg.variables[program:upper()]).. " "..args
      local pipe = io.popen(fs.command_at(directory, fs.quiet_stderr(command)))
      if not pipe then return nil end
      local url = pipe:read("*a"):match("^([^\r\n]+)")
      pipe:close()
      if not url then return nil end
      if not util.starts_with(url, program.."://") then
         url = program.."+"..url
      end
   
      if simple_scm_protocols[dir.split_url(url)] then
         return url
      end
   end
   
   local function detect_scm_url(directory)
      return detect_url_from_command("git", "config --get remote.origin.url", directory) or
         detect_url_from_command("hg", "paths default", directory)
   end

   detect_url = function(url_or_dir)
      if url_or_dir:match("://") then
         return url_or_dir
      else
         return detect_scm_url(url_or_dir) or "*** please add URL for source tarball, zip or repository here ***"
      end
   end
end

local function detect_homepage(url, homepage)
   if homepage then
      return homepage
   end
   local url_protocol, url_path = dir.split_url(url)

   if simple_scm_protocols[url_protocol] then
      for _, domain in ipairs({"github.com", "bitbucket.org", "gitlab.com"}) do
         if util.starts_with(url_path, domain) then
            return "https://"..url_path:gsub("%.git$", "")
         end
      end
   end

   return "*** please enter a project homepage ***"
end

local function detect_description()
   local fd = open_file("README.md") or open_file("README")
   if not fd then return end
   local data = fd:read("*a")
   fd:close()
   local paragraph = data:match("\n\n([^%[].-)\n\n")
   if not paragraph then paragraph = data:match("\n\n(.*)") end
   local summary, detailed
   if paragraph then
      detailed = paragraph

      if #paragraph < 80 then
         summary = paragraph:gsub("\n", "")
      else
         summary = paragraph:gsub("\n", " "):match("([^.]*%.) ")
      end
   end
   return summary, detailed
end

local function detect_mit_license(data)
   local strip_copyright = (data:gsub("Copyright [^\n]*\n", ""))
   local sum = 0
   for i = 1, #strip_copyright do
      local num = string.byte(strip_copyright:sub(i,i))
      if num > 32 and num <= 128 then
         sum = sum + num
      end
   end
   return sum == 78656
end

local function check_license()
   local fd = open_file("COPYING") or open_file("LICENSE") or open_file("MIT-LICENSE.txt")
   if not fd then return nil end
   local data = fd:read("*a")
   fd:close()
   if detect_mit_license(data) then
      return "MIT", data
   end
   return nil, data
end

local function fill_as_builtin(rockspec, libs)
   rockspec.build.type = "builtin"

   local incdirs, libdirs
   if libs then
      incdirs, libdirs = {}, {}
      for _, lib in ipairs(libs) do
         local upper = lib:upper()
         incdirs[#incdirs+1] = "$("..upper.."_INCDIR)"
         libdirs[#libdirs+1] = "$("..upper.."_LIBDIR)"
      end
   end
   
   rockspec.build.modules, rockspec.build.install, rockspec.build.copy_directories = builtin.autodetect_modules(libs, incdirs, libdirs)
end

local function rockspec_cleanup(rockspec)
   rockspec.source.file = nil
   rockspec.source.protocol = nil
   rockspec.source.identifier = nil
   rockspec.source.dir = nil
   rockspec.source.dir_set = nil
   rockspec.source.pathname = nil
   rockspec.variables = nil
   rockspec.name = nil
   rockspec.format_is_at_least = nil
   rockspec.local_abs_filename = nil
   rockspec.rocks_provided = nil
   for _, list in ipairs({"dependencies", "build_dependencies", "test_dependencies"}) do
      if rockspec[list] and not next(rockspec[list]) then
         rockspec[list] = nil
      end
   end
end

function luarocks.write_rockspec(values, name, version, url_or_dir)

   --name = util.adjust_name_and_namespace(name, values)
   fs.init()

   set_rock_tree(tree)

   if not name then
      url_or_dir = "."
   elseif not version then
      url_or_dir = name
      name = nil
   elseif not url_or_dir then
      url_or_dir = version
      version = nil
   end

   if values["tag"] then
      if not version then
         version = values["tag"]:gsub("^v", "")
      end
   end

   local protocol, pathname = dir.split_url(url_or_dir)
   if protocol == "file" then
      if pathname == "." then
         name = name or dir.base_name(fs.current_dir())
      end
   elseif dir.is_basic_protocol(protocol) then
      local filename = dir.base_name(url_or_dir)
      local newname, newversion = filename:match("(.*)-([^-]+)")
      if newname then
         name = name or newname
         version = version or newversion:gsub("%.[a-z]+$", ""):gsub("%.tar$", "")
      end
   else
      name = name or dir.base_name(url_or_dir):gsub("%.[^.]+$", "")
   end

   if not name then
      return nil, "Could not infer rock name. "
   end
   version = version or "dev"

   local filename = values["output"] or dir.path(fs.current_dir(), name:lower().."-"..version.."-1.rockspec")
   
   local url = detect_url(url_or_dir)
   local homepage = detect_homepage(url, values["homepage"])
   
   local rockspec, err = rockspecs.from_persisted_table(filename, {
      rockspec_format = values["rockspec-format"],
      package = name,
      version = version.."-1",
      source = {
         url = url,
         tag = values["tag"],
      },
      description = {
         summary = values["summary"] or "*** please specify description summary ***",
         detailed = values["detailed"] or "*** please enter a detailed description ***",
         homepage = homepage,
         license = values["license"] or "*** please specify a license ***",
      },
      dependencies = {
         lua_version_dep[values["lua-version"]],
      },
      build = {},
   })
   assert(not err, err)
   rockspec.source.protocol = protocol
   
   local warnings = {}
   if not next(rockspec.dependencies) then
      --util.warning("Please specify supported Lua version with --lua-version=<ver>. "..util.see_help("write_rockspec"))
      table.insert(warnings, "Please specify supported Lua version with --lua-version=<ver>. ")
   end
   
   local local_dir = url_or_dir

   if url_or_dir:match("://") then
      rockspec.source.file = dir.base_name(url_or_dir)
      if not dir.is_basic_protocol(rockspec.source.protocol) then
         if version ~= "dev" then
            rockspec.source.tag = values["tag"] or "v" .. version
         end
      end
      rockspec.source.dir = nil
      local ok, base_dir, temp_dir = fetch_url(rockspec)
      if ok then
         if base_dir ~= dir.base_name(url_or_dir) then
            rockspec.source.dir = base_dir
         end
      end
      if base_dir then
         local_dir = dir.path(temp_dir, base_dir)
      else
         local_dir = nil
      end
   end
   
   if not local_dir then
      local_dir = "."
   end
   
   local libs = nil
   if values["lib"] then
      libs = {}
      rockspec.external_dependencies = {}
      for lib in values["lib"]:gmatch("([^,]+)") do
         table.insert(libs, lib)
         rockspec.external_dependencies[lib:upper()] = {
            library = lib
         }
      end
   end

   local ok, err = fs.change_dir(local_dir)
   if not ok then return nil, "Failed reaching files from project - error entering directory "..local_dir end

   if not (values["summary"] and values["detailed"]) then
      local summary, detailed = detect_description()
      rockspec.description.summary = values["summary"] or summary
      rockspec.description.detailed = values["detailed"] or detailed
   end

   if not values["license"] then
      local license, fulltext = check_license()
      if license then
         rockspec.description.license = license
      elseif license then
         table.insert(warnings, "Could not auto-detect type for project license. Please fill in the source.license field manually or provide license in the input table.")
      end
   end
   
   fill_as_builtin(rockspec, libs)
      
   rockspec_cleanup(rockspec)
   
   persist.save_from_table(filename, rockspec, type_rockspec.order)

   return true, "Wrote template at "..filename.." -- you should now edit and finish it."
end

local function try_replace(tbl, field, old, new)
   if not tbl[field] then
      return false
   end
   local old_field = tbl[field]
   local new_field = tbl[field]:gsub(old, new)
   if new_field ~= old_field then
      --util.printout("Guessing new '"..field.."' field as "..new_field)
      tbl[field] = new_field
      return true      
   end
   return false
end

-- Try to download source file using URL from a rockspec.
-- If it specified MD5, update it.
-- @return (true, false) if MD5 was not specified or it stayed same,
-- (true, true) if MD5 changed, (nil, string) on error.
local function check_url_and_update_md5(out_rs)
   local file, temp_dir = fetch.fetch_url_at_temp_dir(out_rs.source.url, "luarocks-new-version-"..out_rs.package)
   if not file then
      --util.warning("invalid URL - "..temp_dir)
      return true, false
   end

   local inferred_dir, found_dir = fetch.find_base_dir(file, temp_dir, out_rs.source.url, out_rs.source.dir)
   if not inferred_dir then
      return nil, found_dir
   end

   if found_dir and found_dir ~= inferred_dir then
      out_rs.source.dir = found_dir
   end

   if file then
      if out_rs.source.md5 then
         --util.printout("File successfully downloaded. Updating MD5 checksum...")
         local new_md5, err = fs.get_md5(file)
         if not new_md5 then
            return nil, err
         end
         local old_md5 = out_rs.source.md5
         out_rs.source.md5 = new_md5
         return true, new_md5 ~= old_md5
      else
         --util.printout("File successfully downloaded.")
         return true, false
      end
   end
end
 
local function update_source_section(out_rs, url, tag, old_ver, new_ver)
   if tag then
      out_rs.source.tag = tag
   end
   if url then
      out_rs.source.url = url
      return check_url_and_update_md5(out_rs)
   end
   if new_ver == old_ver then
      return true
   end
   if out_rs.source.dir then
      try_replace(out_rs.source, "dir", old_ver, new_ver)
   end
   if out_rs.source.file then
      try_replace(out_rs.source, "file", old_ver, new_ver)
   end
   if try_replace(out_rs.source, "url", old_ver, new_ver) then
      return check_url_and_update_md5(out_rs)
   end
   if tag or try_replace(out_rs.source, "tag", old_ver, new_ver) then
      return true
   end
   -- Couldn't replace anything significant, use the old URL.
   local ok, md5_changed = check_url_and_update_md5(out_rs)
   if not ok then
      return nil, md5_changed
   end
   if md5_changed then
      return true, "URL is the same, but MD5 has changed. Old rockspec is broken."
   end
   return true
end
 
function luarocks.new_version(input, version, url, tag)

   fs.init()

   -- Even though this function doesn't necessarily require a tree argument, it needs to calll this function to not break - fetch.load_local_rockspec()
   set_rock_tree(tree)

   if not input then
      local err
      input, err = util.get_default_rockspec()
      if not input then
         return nil, err
      end
   end
   assert(type(input) == "string")
   
   local filename, err
   if input:match("rockspec$") then
      filename, err = fetch.fetch_url(input)
      if not filename then
         return nil, err
      end
   else
      filename, err = download.download("rockspec", input:lower())
      if not filename then
         return nil, err
      end
   end

   local valid_rs, err = fetch.load_rockspec(filename)
   if not valid_rs then
      return nil, err
   end

   local old_ver, old_rev = valid_rs.version:match("(.*)%-(%d+)$")
   local new_ver, new_rev

   if tag and not version then
      version = tag:gsub("^v", "")
   end
   
   if version then
      new_ver, new_rev = version:match("(.*)%-(%d+)$")
      new_rev = tonumber(new_rev)
      if not new_rev then
         new_ver = version
         new_rev = 1
      end
   else
      new_ver = old_ver
      new_rev = tonumber(old_rev) + 1
   end
   local new_rockver = new_ver:gsub("-", "")
   
   local out_rs, err = persist.load_into_table(filename)
   local out_name = out_rs.package:lower()
   out_rs.version = new_rockver.."-"..new_rev

   local ok, err = update_source_section(out_rs, url, tag, old_ver, new_ver)
   if not ok then return nil, err end
   if ok then
      md5_changed = err
   end

   if out_rs.build and out_rs.build.type == "module" then
      out_rs.build.type = "builtin"
   end
   
   local out_filename = out_name.."-"..new_rockver.."-"..new_rev..".rockspec"
   
   persist.save_from_table(out_filename, out_rs, type_rockspec.order)
   
   --util.printout("Wrote "..out_filename)

   local valid_out_rs, err = fetch.load_local_rockspec(out_filename)
   if not valid_out_rs then
      return nil, "Failed loading generated rockspec: "..err
   end
   
   return true, "Wrote "..out_filename, md5_changed
end

local function config_file(conf)
   if conf.ok then
      return dir.normalize(conf.file)
   else
      return "file not found"
   end
end

function luarocks.current_config()

   local config_table = {}

   config_table["lua-incdir"] = cfg.variables.LUA_INCDIR
   config_table["lua-libdir"] = cfg.variables.LUA_LIBDIR
   config_table["lua-ver"] = cfg.lua_version
      
   local conf = cfg.which_config()
   config_table["system-config"] = config_file(conf.system)
   config_table["user-config"] = config_file(conf.user)
   
   config_table["rock-trees"] = cfg.rocks_trees
   
   return config_table
end

local function build_rock(rock_filename, opts)
   assert(type(rock_filename) == "string")
   assert(opts:type() == "build.opts")

   local ok, err, errcode

   local unpack_dir
   unpack_dir, err, errcode = fetch.fetch_and_unpack_rock(rock_filename)
   if not unpack_dir then
      return nil, err, errcode
   end

   local rockspec_filename = path.rockspec_name_from_rock(rock_filename)

   ok, err = fs.change_dir(unpack_dir)
   if not ok then return nil, err end

   local rockspec
   rockspec, err, errcode = fetch.load_rockspec(rockspec_filename)
   if not rockspec then
      return nil, err, errcode
   end

   ok, err, errcode = build.build_rockspec(rockspec, opts)

   fs.pop_dir()
   return ok, err, errcode
end

local function do_build(ns_name, version, opts)
   assert(type(ns_name) == "string")
   assert(version == nil or type(version) == "string")
   assert(opts:type() == "build.opts")

   local url, err
   if ns_name:match("%.rockspec$") or ns_name:match("%.rock$") then
      url = ns_name
   else
      url, err = search.find_src_or_rockspec(ns_name, version)
      if not url then
         return nil, err
      end
      local _, namespace = util.split_namespace(ns_name)
      opts.namespace = namespace
   end

   if url:match("%.rockspec$") then
      local rockspec, err, errcode = fetch.load_rockspec(url)
      if not rockspec then
         return nil, err, errcode
      end
      return build.build_rockspec(rockspec, opts)
   end

   if url:match("%.src%.rock$") then
      opts.need_to_fetch = false
   end

   return build_rock(url, opts)
end

function luarocks.build(name, version, tree, only_deps, keep, pack_binary_rock, branch)
   
   fs.init()

   -- Even though this function doesn't necessarily require a tree argument, it needs to call this function to not break - fetch.load_local_rockspec()
   set_rock_tree(tree)

   assert(type(name) == "string" or not name)
   assert(type(version) == "string" or not version)
   
   if not name then
      return make.command(flags)
   end

   --name = util.adjust_name_and_namespace(name, flags)

   local opts = build.opts({
      need_to_fetch = true,
      minimal_mode = false,
      --deps_mode = deps.get_deps_mode(flags),
      deps_mode = cfg.deps_mode,
      build_only_deps = not not only_deps,
      --namespace = flags["namespace"],
      branch = not not branch,
   })

   if pack_binary_rock then
      return pack.pack_binary_rock(name, version, function()
         opts.build_only_deps = false
         return do_build(name, version, opts)
      end)
   end
   
   local ok, err = fs.check_command_permissions_no_flags()
   if not ok then
      return nil, err, cmd.errorcodes.PERMISSIONDENIED
   end

   ok, err = do_build(name, version, opts)
   if not ok then return nil, err end
   name, version = ok, err

   --[[
   if not opts.build_only_deps then
      if (not flags["keep"]) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, flags["force"], flags["force-fast"])
         if not ok then
            util.printerr(err)
         end
      end
   end
   --]]

   --writer.check_dependencies(nil, deps.get_deps_mode(flags))
   return name, version
end

function luarocks.install_binary_rock(rock_file, deps_mode, namespace)
   assert(type(rock_file) == "string")
   assert(type(deps_mode) == "string")
   --assert(type(namespace) == "string" or namespace == nil)

   local name, version, arch = path.parse_name(rock_file)
   if not name then
      return nil, "Filename "..rock_file.." does not match format 'name-version-revision.arch.rock'."
   end
   
   if arch ~= "all" and arch ~= cfg.arch then
      return nil, "Incompatible architecture "..arch, "arch"
   end
   if repos.is_installed(name, version) then
      repos.delete_version(name, version, deps_mode)
   end
   
   local rollback = util.schedule_function(function()
      fs.delete(path.install_dir(name, version))
      fs.remove_dir_if_empty(path.versions_dir(name))
   end)
   
   local ok, err, errcode = fetch.fetch_and_unpack_rock(rock_file, path.install_dir(name, version))
   if not ok then return nil, err, errcode end
   
   local rockspec, err, errcode = fetch.load_rockspec(path.rockspec_file(name, version))
   if err then
      return nil, "Failed loading rockspec for installed package: "..err, errcode
   end

   if deps_mode == "none" then
      util.warning("skipping dependency checks.")
   else
      ok, err, errcode = deps.check_external_deps(rockspec, "install")
      if err then return nil, err, errcode end
   end

   -- For compatibility with .rock files built with LuaRocks 1
   if not fs.exists(path.rock_manifest_file(name, version)) then
      ok, err = writer.make_rock_manifest(name, version)
      if err then return nil, err end
   end

   --[[
   if namespace then
      ok, err = writer.make_namespace_file(name, version, namespace)
      if err then return nil, err end
   end
   --]]

   if deps_mode ~= "none" then
      ok, err, errcode = deps.fulfill_dependencies(rockspec, "dependencies", deps_mode)
      if err then return nil, err, errcode end
   end

   ok, err = repos.deploy_files(name, version, repos.should_wrap_bin_scripts(rockspec), deps_mode)
   if err then return nil, err end

   util.remove_scheduled_function(rollback)
   rollback = util.schedule_function(function()
      repos.delete_version(name, version, deps_mode)
   end)

   ok, err = repos.run_hook(rockspec, "post_install")
   if err then return nil, err end

   util.announce_install(rockspec)
   util.remove_scheduled_function(rollback)
   return name, version
end


function luarocks.install_binary_rock_deps(rock_file, deps_mode)
   assert(type(rock_file) == "string")

   local name, version, arch = path.parse_name(rock_file)
   if not name then
      return nil, "Filename "..rock_file.." does not match format 'name-version-revision.arch.rock'."
   end
   
   if arch ~= "all" and arch ~= cfg.arch then
      return nil, "Incompatible architecture "..arch, "arch"
   end

   local ok, err, errcode = fetch.fetch_and_unpack_rock(rock_file, path.install_dir(name, version))
   if not ok then return nil, err, errcode end
   
   local rockspec, err, errcode = fetch.load_rockspec(path.rockspec_file(name, version))
   if err then
      return nil, "Failed loading rockspec for installed package: "..err, errcode
   end

   ok, err, errcode = deps.fulfill_dependencies(rockspec, "dependencies", deps_mode)
   if err then return nil, err, errcode end

   util.printout()
   util.printout("Successfully installed dependencies for " ..name.." "..version)

   return name, version
end

local function install_rock_file_deps(filename, deps_mode)
   local name, version = luarocks.install_binary_rock_deps(filename, deps_mode)
   if not name then return nil, version end

   writer.check_dependencies(nil, deps_mode)
   return name, version
end

local function install_rock_file(filename, namespace, deps_mode, keep, force, force_fast)
   assert(type(filename) == "string")
   assert(type(namespace) == "string" or namespace == nil)
   assert(type(deps_mode) == "string")
   assert(type(keep) == "boolean" or keep == nil)
   assert(type(force) == "boolean" or force == nil)
   assert(type(force_fast) == "boolean" or force_fast == nil)

   local name, version = luarocks.install_binary_rock(filename, deps_mode, namespace)
   if not name then return nil, version end

   if (not keep) and not cfg.keep_other_versions then
      local ok, err = remove.remove_other_versions(name, version, force, force_fast)
      if not ok then util.printerr(err) end
   end

   writer.check_dependencies(nil, deps_mode)
   return name, version
end

function luarocks.install(name, version, tree, only_deps, keep)

   fs.init()
   
   if type(name) ~= "string" then
      return nil, "Argument missing. "
   end

   --name = util.adjust_name_and_namespace(name, flags)

   local ok, err = fs.check_command_permissions_no_flags()
   if not ok then return nil, err, cmd.errorcodes.PERMISSIONDENIED end

   if name:match("%.rockspec$") or name:match("%.src%.rock$") then
      return luarocks.build(name, version, tree, only_deps, keep, pack_binary_rock, branch)
   --[[elseif name:match("%.rock$") then
      local deps_mode = deps.get_deps_mode(flags)
      if flags["only-deps"] then
         return install_rock_file_deps(name, deps_mode)
      else
         return install_rock_file(name, flags["namespace"], deps_mode, flags["keep"], flags["force"], flags["force-fast"])
      end--]]
   else
      local url, err = search.find_suitable_rock(queries.new(name:lower(), version))
      if not url then
         return nil, err
      end
      --util.printout("Installing "..url)
      return luarocks.install(url, version, tree, only_deps, keep)
   end
end

return luarocks