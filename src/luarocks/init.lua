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

local remove = require("luarocks.remove")
local deps = require("luarocks.deps")
local writer = require("luarocks.manif.writer")

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

--- force = nil for not forcing
-- "force" for force
-- "force-fast" for fast-force
function luarocks.remove(name, version, force)

   set_rock_tree(tree)

   cfg.rocks_dir = cfg.rocks_dir:gsub("/+$", "")
   cfg.deploy_bin_dir = cfg.deploy_bin_dir:gsub("/+$", "")
   cfg.deploy_lua_dir = cfg.deploy_lua_dir:gsub("/+$", "")
   cfg.deploy_lib_dir = cfg.deploy_lib_dir:gsub("/+$", "")
   
   cfg.variables.ROCKS_TREE = cfg.rocks_dir
   cfg.variables.SCRIPTS_DIR = cfg.deploy_bin_dir


   if type(name) ~= "string" then
      return nil, "Argument missing. "
   end
   
   --local deps_mode = flags["deps-mode"] or cfg.deps_mode
   deps_mode = cfg.deps_mode
   --

   --local ok, err = fs.check_command_permissions_no_flags(flags)
   local ok, err = fs.check_command_permissions_no_flags()
   --
   if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end
   
   local rock_type = name:match("%.(rock)$") or name:match("%.(rockspec)$")
   local filename = name
   if rock_type then
      name, version = path.parse_name(filename)
      if not name then return nil, "Invalid "..rock_type.." filename: "..filename end
   end

   local results = {}
   name = name:lower()
   search.manifest_search(results, cfg.rocks_dir, search.make_query(name, version))
   if not results[name] then
      return nil, "Could not find rock '"..name..(version and " "..version or "").."' in "..path.rocks_tree_to_string(cfg.root_dir)
   end

   --local ok, err = remove.remove_search_results(results, name, deps_mode, flags["force"], flags["force-fast"])
   local ok, err = nil, nil
   if force == "force" then
   	  ok, err = remove.remove_search_results(results, name, deps_mode, true, false)
   elseif force == "force-fast" then
   	  ok, err = remove.remove_search_results(results, name, deps_mode, false, true)
   else
   	  ok, err = remove.remove_search_results(results, name, deps_mode, false, false)
   end
   --

   if not ok then
      return nil, err
   end

   --writer.check_dependencies(nil, deps.get_deps_mode(flags))
   --

   return true
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

local function get_url(rockspec)
   local file, temp_dir, err_code, err_file, err_temp_dir = fetch.fetch_sources(rockspec, false)
   if err_code == "source.dir" then
      file, temp_dir = err_file, err_temp_dir
   elseif not file then
      --util.warning("Could not fetch sources - "..temp_dir)
      return false, "Could not fetch sources - "..temp_dir
   end
   --util.printout("File successfully downloaded. Making checksum and checking base dir...")
   if fetch.is_basic_protocol(rockspec.source.protocol) then
      rockspec.source.md5 = fs.get_md5(file)
   end
   local inferred_dir, found_dir = fetch.find_base_dir(file, temp_dir, rockspec.source.url)
   return true, found_dir or inferred_dir, temp_dir
end

local function configure_lua_version(rockspec, luaver)
   if luaver == "5.1" then
      table.insert(rockspec.dependencies, "lua ~> 5.1")
   elseif luaver == "5.2" then
      table.insert(rockspec.dependencies, "lua ~> 5.2")
   elseif luaver == "5.3" then
      table.insert(rockspec.dependencies, "lua ~> 5.3")
   elseif luaver == "5.1,5.2" then
      table.insert(rockspec.dependencies, "lua >= 5.1, < 5.3")
   elseif luaver == "5.2,5.3" then
      table.insert(rockspec.dependencies, "lua >= 5.2, < 5.4")
   elseif luaver == "5.1,5.2,5.3" then
      table.insert(rockspec.dependencies, "lua >= 5.1, < 5.4")
   else
      --util.warning("Please specify supported Lua version with --lua-version=<ver>. "..util.see_help("write_rockspec"))
      table.insert(rockspec.dependencies, "*** please specify lua version dependencies here ***")
   end
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

local simple_scm_protocols = {
   git = true, ["git+http"] = true, ["git+https"] = true,
   hg = true, ["hg+http"] = true, ["hg+https"] = true
}

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

local function open_license(rockspec)
   local fd = open_file("COPYING") or open_file("LICENSE") or open_file("MIT-LICENSE.txt")
   if not fd then return nil end
   local data = fd:read("*a")
   fd:close()
   local is_mit = detect_mit_license(data)
   return is_mit
end

local function get_cmod_name(file)
   local fd = open_file(file)
   if not fd then return nil end
   local data = fd:read("*a")
   fd:close()
   return (data:match("int%s+luaopen_([a-zA-Z0-9_]+)"))
end

local luamod_blacklist = {
   test = true,
   tests = true,
}

local function fill_as_builtin(rockspec, libs)
   rockspec.build.type = "builtin"
   rockspec.build.modules = {}
   local prefix = ""

   for _, parent in ipairs({"src", "lua"}) do
      if fs.is_dir(parent) then
         fs.change_dir(parent)
         prefix = parent.."/"
         break
      end
   end
   
   local incdirs, libdirs
   if libs then
      incdirs, libdirs = {}, {}
      for _, lib in ipairs(libs) do
         local upper = lib:upper()
         incdirs[#incdirs+1] = "$("..upper.."_INCDIR)"
         libdirs[#libdirs+1] = "$("..upper.."_LIBDIR)"
      end
   end

   for _, file in ipairs(fs.find()) do
      local luamod = file:match("(.*)%.lua$")
      if luamod and not luamod_blacklist[luamod] then
         rockspec.build.modules[path.path_to_module(file)] = prefix..file
      else
         local cmod = file:match("(.*)%.c$")
         if cmod then
            local modname = get_cmod_name(file) or path.path_to_module(file:gsub("%.c$", ".lua"))
            rockspec.build.modules[modname] = {
               sources = prefix..file,
               libraries = libs,
               incdirs = incdirs,
               libdirs = libdirs,
            }
         end
      end
   end
   
   for _, directory in ipairs({ "doc", "docs", "samples", "tests" }) do
      if fs.is_dir(directory) then
         if not rockspec.build.copy_directories then
            rockspec.build.copy_directories = {}
         end
         table.insert(rockspec.build.copy_directories, directory)
      end
   end
   
   if prefix ~= "" then
      fs.pop_dir()
   end
end

local function rockspec_cleanup(rockspec)
   rockspec.source.file = nil
   rockspec.source.protocol = nil
   rockspec.variables = nil
   rockspec.name = nil
   rockspec.format_is_at_least = nil
end


function luarocks.write_rockspec(values, name, version, url_or_dir)

   -- Even though this function doesn't necessarily require a tree argument, it needs to calll this function to not break - fetch.load_local_rockspec()
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
   elseif fetch.is_basic_protocol(protocol) then
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

   local rockspec = {
      rockspec_format = values["rockspec-format"],
      package = name,
      name = name:lower(),
      version = version.."-1",
      source = {
         url = "*** please add URL for source tarball, zip or repository here ***",
         tag = values["tag"],
      },
      description = {
         summary = values["summary"] or "*** please specify description summary ***",
         detailed = values["detailed"] or "*** please enter a detailed description ***",
         homepage = values["homepage"] or "*** please enter a project homepage ***",
         license = values["license"] or "*** please specify a license ***",
      },
      dependencies = {},
      build = {},
   }
   path.configure_paths(rockspec)
   rockspec.source.protocol = protocol
   rockspec.format_is_at_least = vers.format_is_at_least
   
   configure_lua_version(rockspec, values["lua-version"])
   
   local local_dir = url_or_dir

   if url_or_dir:match("://") then
      rockspec.source.url = url_or_dir
      rockspec.source.file = dir.base_name(url_or_dir)
      rockspec.source.dir = "dummy"
      if not fetch.is_basic_protocol(rockspec.source.protocol) then
         if version ~= "dev" then
            rockspec.source.tag = values["tag"] or "v" .. version
         end
      end
      rockspec.source.dir = nil
      local ok, base_dir, temp_dir = get_url(rockspec)
      if ok then
         if base_dir ~= dir.base_name(url_or_dir) then
            rockspec.source.dir = base_dir
         end
      else
         local err_msg = base_dir
         return false, err_msg
      end
      if base_dir then
         local_dir = dir.path(temp_dir, base_dir)
      else
         local_dir = nil
      end
   else
      rockspec.source.url = detect_scm_url(local_dir) or rockspec.source.url
   end
   
   if not local_dir then
      local_dir = "."
   end

   if not values["homepage"] then
      local url_protocol, url_path = dir.split_url(rockspec.source.url)

      if simple_scm_protocols[url_protocol] then
         for _, domain in ipairs({"github.com", "bitbucket.org", "gitlab.com"}) do
            if util.starts_with(url_path, domain) then
               rockspec.description.homepage = "https://"..url_path:gsub("%.git$", "")
               break
            end
         end
      end
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

   if (not values["summary"]) or (not values["detailed"]) then
      local summary, detailed = detect_description()
      rockspec.description.summary = values["summary"] or summary
      rockspec.description.detailed = values["detailed"] or detailed
   end

   local is_mit = open_license(rockspec)
   
   if is_mit and not values["license"] then
      rockspec.description.license = "MIT"
   end
   
   fill_as_builtin(rockspec, libs)
      
   rockspec_cleanup(rockspec)
   
   persist.save_from_table(filename, rockspec, type_rockspec.order)

   return true, "Wrote template at "..filename.." -- you should now edit and finish it."
end

return luarocks