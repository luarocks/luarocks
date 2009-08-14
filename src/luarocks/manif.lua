
--- Functions for querying and manipulating manifest files.
module("luarocks.manif", package.seeall)

local util = require("luarocks.util")
local fs = require("luarocks.fs")
local search = require("luarocks.search")
local rep = require("luarocks.rep")
local deps = require("luarocks.deps")
local cfg = require("luarocks.cfg")
local persist = require("luarocks.persist")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local manif_core = require("luarocks.manif_core")

local function find_module_at_file(file, modules)
   for module, location in pairs(modules) do
      if file == location then
         return module
      end
   end
end

local function rename_module(file, pkgid)
   local path = dir.dir_name(file)
   local name = dir.base_name(file)
   local pkgid = pkgid:gsub("[/.-]", "_")
   return dir.path(path, pkgid.."-"..name)
end

local function update_global_lib(repo, manifest)
   fs.make_dir(cfg.lua_modules_dir)
   fs.make_dir(cfg.bin_modules_dir)
   for rock, modules in pairs(manifest.modules) do
      for module, file in pairs(modules) do
         local module_type, modules_dir
         
         if file:match("%."..cfg.lua_extension.."$") then
            module_type = "lua"
            modules_dir = cfg.lua_modules_dir
         else
            module_type = "bin"
            modules_dir = cfg.bin_modules_dir
         end

         if not file:match("^"..modules_dir) then
            local path_in_rock = dir.strip_base_dir(file:sub(#dir.path(repo, module)+2))
            local module_dir = dir.dir_name(path_in_rock)
            local dest = dir.path(modules_dir, path_in_rock)
            if module_dir ~= "" then
               fs.make_dir(dir.dir_name(dest))
            end
            if not fs.exists(dest) then
               fs.move(file, dest)
               fs.remove_dir_tree_if_empty(dir.dir_name(file))
               manifest.modules[rock][module] = dest
            else
               local current = find_module_at_file(dest, modules)
               if not current then
                  util.warning("installed file not tracked by LuaRocks: "..dest)
               else
                  local newname = rename_module(dest, current)
                  if fs.exists(newname) then
                     util.warning("conflict when tracking modules: "..newname.." exists.")
                  else
                     local ok, err = fs.move(dest, newname)
                     if ok then
                        manifest.modules[rock][current] = newname
                        fs.move(file, dest)
                        fs.remove_dir_tree_if_empty(dir.dir_name(file))
                        manifest.modules[rock][module] = dest
                     else
                        util.warning(err)
                     end
                  end
               end
            end
         else
            -- print("File already in place.")
         end
      end
   end
end

--- Load a local or remote manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_local_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string, [string]): A table representing the manifest,
-- or nil followed by an error message and an optional error code.
function load_manifest(repo_url)
   assert(type(repo_url) == "string")
   
   if manif_core.manifest_cache[repo_url] then
      return manif_core.manifest_cache[repo_url]
   end

   local protocol, pathname = dir.split_url(repo_url)
   if protocol == "file" then
      pathname = dir.path(pathname, "manifest")
   else
      local url = dir.path(repo_url, "manifest")
      local name = repo_url:gsub("[/:]","_")
      local file, err, errcode = fetch.fetch_url_at_temp_dir(url, "luarocks-manifest-"..name)
      if not file then
         return nil, "Failed fetching manifest for "..repo_url, errcode
      end
      pathname = file
   end
   return manif_core.manifest_loader(pathname, repo_url)
end

--- Sort function for ordering rock identifiers in a manifest's
-- modules table. Rocks are ordered alphabetically by name, and then
-- by version which greater first.
-- @param a string: Version to compare.
-- @param b string: Version to compare.
-- @return boolean: The comparison result, according to the
-- rule outlined above.
local function sort_pkgs(a, b)
   assert(type(a) == "string")
   assert(type(b) == "string")

   local na, va = a:match("(.*)/(.*)$")
   local nb, vb = b:match("(.*)/(.*)$")
   
   return (na == nb) and deps.compare_versions(va, vb) or na < nb
end

--- Output a table listing items of a package.
-- @param itemsfn function: a function for obtaining items of a package.
-- pkg and version will be passed to it; it should return a table with
-- items as keys.
-- @param pkg string: package name
-- @param version string: package version
-- @param tbl table: the package matching table: keys should be item names
-- and values arrays of strings with packages names in "name/version" format.
local function store_package_items(itemsfn, pkg, version, tbl)
   assert(type(itemsfn) == "function")
   assert(type(pkg) == "string")
   assert(type(version) == "string")
   assert(type(tbl) == "table")

   local pkg_version = pkg.."/"..version
   local result = {}
   for item, path in pairs(itemsfn(pkg, version)) do
      result[item] = path
      if not tbl[item] then
         tbl[item] = {}
      end
      tbl[item][pkg_version] = path
   end
   return result
end

--- Sort items of a package matching table by version number (higher versions first).
-- @param tbl table: the package matching table: keys should be strings
-- and values arrays of strings with packages names in "name/version" format.
local function sort_package_matching_table(tbl)
   assert(type(tbl) == "table")
   
   if next(tbl) then
      for item, pkgs in pairs(tbl) do
         if #pkgs > 1 then
            table.sort(pkgs, sort_pkgs)
            -- Remove duplicates from the sorted array.
            local prev = nil
            local i = 1
            while pkgs[i] do
               local curr = pkgs[i]
               if curr == prev then
                  table.remove(pkgs, i)
               else
                  prev = curr
                  i = i + 1
               end
            end
         end
      end
   end
end

--- Commit manifest to disk in given local repository.
-- @param repo string: The directory of the local repository.
-- @param manifest table: The manifest table
-- @return boolean or (nil, string): true if successful, or nil and a
-- message in case of errors.
local function save_manifest(repo, manifest)
   assert(type(repo) == "string")
   assert(type(manifest) == "table")

   local filename = dir.path(repo, "manifest")
   return persist.save_from_table(filename, manifest)
end

--- Process the dependencies of a package to determine its dependency
-- chain for loading modules.
-- @param name string: Package name.
-- @param version string: Package version.
-- @return (table, table): A table listing dependencies as string-string pairs
-- of names and versions, and a similar table of missing dependencies.
local function update_dependencies(manifest)
   for pkg, versions in pairs(manifest.repository) do
      for version, repos in pairs(versions) do
         local current = pkg.." "..version
         for _, repo in ipairs(repos) do
            if repo.arch == "installed" then
               local missing
               repo.dependencies, missing = deps.scan_deps({}, {}, manifest, pkg, version)
               repo.dependencies[pkg] = nil
               if missing then
                  for miss, _ in pairs(missing) do
                     if miss == current then
                        print("Tree inconsistency detected: "..current.." has no rockspec.")
                     else
                        print("Missing dependency for "..pkg.." "..version..": "..miss)
                     end
                  end
               end
            end
         end
      end
   end
end

--- Store search results in a manifest table.
-- @param results table: The search results as returned by search.disk_search.
-- @param manifest table: A manifest table (must contain repository, modules, commands tables).
local function store_results(results, manifest)
   assert(type(results) == "table")
   assert(type(manifest) == "table")

   for pkg, versions in pairs(results) do
      local pkgtable = manifest.repository[pkg] or {}
      for version, entries in pairs(versions) do
         local versiontable = {}
         for _, entry in ipairs(entries) do
            local entrytable = {}
            entrytable.arch = entry.arch
            if entry.arch == "installed" then
               entrytable.modules = store_package_items(rep.package_modules, pkg, version, manifest.modules)
               entrytable.commands = store_package_items(rep.package_commands, pkg, version, manifest.commands)
            end
            table.insert(versiontable, entrytable)
         end
         pkgtable[version] = versiontable
      end
      manifest.repository[pkg] = pkgtable
   end
   update_dependencies(manifest)
   sort_package_matching_table(manifest.modules)
   sort_package_matching_table(manifest.commands)
end

--- Load a manifest file from a local repository and add to the repository
-- information with regard to the given name and version.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param name string: Name of a package from the repository.
-- @param version string: Version of a package from the repository.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository configured as cfg.rocks_dir is used.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function update_manifest(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(repo) == "string" or not repo)
   repo = repo or cfg.rocks_dir

   print("Updating manifest for "..repo)

   local manifest, err = load_manifest(repo)
   if not manifest then
      print("No existing manifest. Attempting to rebuild...")
      local ok, err = make_manifest(repo)
      if not ok then
         return nil, err
      end
      manifest, err = load_manifest(repo)
      if not manifest then
         return nil, err
      end
   end

   local results = {[name] = {[version] = {{arch = "installed", repo = repo}}}}
   
   store_results(results, manifest)
   update_global_lib(repo, manifest)
   return save_manifest(repo, manifest)
end

   --- Scan a LuaRocks repository and output a manifest file.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param repo A local repository directory.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function make_manifest(repo)
   assert(type(repo) == "string")

   if not fs.is_dir(repo) then
      return nil, "Cannot access repository at "..repo
   end

   local query = search.make_query("")
   query.exact_name = false
   query.arch = "any"
   local results = search.disk_search(repo, query)
   local manifest = { repository = {}, modules = {}, commands = {} }
   manif_core.manifest_cache[repo] = manifest

   --print(util.show_table(results, "results"))
   --print(util.show_table(manifest, "manifest"))

   store_results(results, manifest)

   --print(util.show_table(manifest, "manifest after store"))

   update_global_lib(repo, manifest)

   --print(util.show_table(manifest, "manifest after update"))

   return save_manifest(repo, manifest)
end

local index_header = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>Available rocks</title>
<meta http-equiv="content-type" content="text/html; charset=iso-8859-1">
<style>
body {
   background-color: white;
   font-family: "bitstream vera sans", "verdana", "sans";
   font-size: 14px;
}
a {
   color: #0000c0;
   text-decoration: none;
}
a:hover {
   text-decoration: underline;
}
td.main {
   border-style: none;
}
blockquote {
   font-size: 12px;
}
td.package {
   background-color: #f0f0f0;
   vertical-align: top;
}
td.spacer {
   height: 5px;
}
td.version {
   background-color: #d0d0d0;
   vertical-align: top;
   text-align: left;
   padding: 5px;
   width: 100px;
}
p.manifest {
   font-size: 8px;
}
</style>
</head>
<body>
<h1>Available rocks</h1>
<p>
Lua modules avaliable from this location for use with <a href="http://www.luarocks.org">LuaRocks</a>:
</p>
<table class="main">
]]

local index_package_start = [[
<td class="package">
<p><a name="$anchor"></a><b>$package</b> - $summary<br/>
</p><blockquote><p>$detailed<br/>
<font size="-1"><a href="$original">latest sources</a> $homepage | License: $license</font></p>
</blockquote></a></td>
<td class="version">
]]

local index_package_end = [[
</td></tr>
<tr><td colspan="2" class="spacer"></td></tr>
]]

local index_footer = [[
</table>
<p class="manifest">
<a href="manifest">manifest file</a>
</p>
</body>
</html>
]]

function make_index(repo)
   if not fs.is_dir(repo) then
      return nil, "Cannot access repository at "..repo
   end
   local manifest = load_manifest(repo)
   local out = io.open(dir.path(repo, "index.html"), "w")
   
   out:write(index_header)
   for package, version_list in util.sortedpairs(manifest.repository) do
      local latest_rockspec = nil
      local output = index_package_start
      for version, data in util.sortedpairs(version_list, deps.compare_versions) do
         local out_versions = {}
         local arches = 0
         output = output..version
         local sep = ':&nbsp;'
         for _, item in ipairs(data) do
            output = output .. sep .. '<a href="$url">'..item.arch..'</a>'
            sep = ',&nbsp;'
            if item.arch == 'rockspec' then
               local rs = ("%s-%s.rockspec"):format(package, version)
               if not latest_rockspec then latest_rockspec = rs end
               output = output:gsub("$url", rs)
            else
               output = output:gsub("$url", ("%s-%s.%s.rock"):format(package, version, item.arch))
            end
         end
         output = output .. '<br/>'
         output = output:gsub("$na", arches)
      end
      output = output .. index_package_end
      if latest_rockspec then
         local rockspec = persist.load_into_table(dir.path(repo, latest_rockspec))
         local vars = {
            anchor = package,
            package = rockspec.package,
            original = rockspec.source.url,
            summary = rockspec.description.summary or "",
            detailed = rockspec.description.detailed or "",
            license = rockspec.description.license or "N/A",
            homepage = rockspec.description.homepage and ("| <a href="..rockspec.description.homepage..">project homepage</a>") or ""
         }
         vars.detailed = vars.detailed:gsub("\n\n", "</p><p>"):gsub("%s+", " ")
         output = output:gsub("$(%w+)", vars)
      else
         output = output:gsub("$anchor", package)
         output = output:gsub("$package", package)
         output = output:gsub("$(%w+)", "")
      end
      out:write(output)
   end
   out:write(index_footer)
   out:close()
end

