
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
local type_check = require("luarocks.type_check")

manifest_cache = {}

--- Get all versions of a package listed in a manifest file.
-- @param name string: a package name.
-- @param manifest table or nil: a manifest table; if not given, the
-- default local manifest table is used.
-- @return table: An array of strings listing installed
-- versions of a package.
function get_versions(name, manifest)
   assert(type(name) == "string")
   assert(type(manifest) == "table" or not manifest)
   
   if not manifest then
      manifest = load_local_manifest(cfg.rocks_dir)
      if not manifest then
         return {}
      end
   end
   
   local item = manifest.repository[name]
   if item then
      return util.keys(item)
   end
   return {}
end

--- Back-end function that actually loads the manifest
-- and stores it in the manifest cache.
-- @param file string: The local filename of the manifest file.
-- @param repo_url string: The repository identifier.
local function manifest_loader(file, repo_url, quick)
   local manifest = persist.load_into_table(file)
   if not manifest then
      return nil, "Failed loading manifest for "..repo_url
   end
   if not quick then
      local ok, err = type_check.type_check_manifest(manifest)
      if not ok then
         return nil, "Error checking manifest: "..err
      end
   end

   manifest_cache[repo_url] = manifest
   return manifest
end

--- Load a local or remote manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_local_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string): A table representing the manifest,
-- or nil followed by an error message.
function load_manifest(repo_url)
   assert(type(repo_url) == "string")
   
   if manifest_cache[repo_url] then
      return manifest_cache[repo_url]
   end

   local protocol, pathname = fs.split_url(repo_url)
   if protocol == "file" then
      pathname = fs.make_path(pathname, "manifest")
   else
      local url = fs.make_path(repo_url, "manifest")
      local name = repo_url:gsub("[/:]","_")
      local file, dir = fetch.fetch_url_at_temp_dir(url, "luarocks-manifest-"..name)
      if not file then
         return nil, "Failed fetching manifest for "..repo_url
      end
      pathname = file
   end
   return manifest_loader(pathname, repo_url)
end

--- Load a local manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @return table or (nil, string): A table representing the manifest,
-- or nil followed by an error message.
function load_local_manifest(repo_url)
   assert(type(repo_url) == "string")

   if manifest_cache[repo_url] then
      return manifest_cache[repo_url]
   end

   local pathname = fs.make_path(repo_url, "manifest")

   return manifest_loader(pathname, repo_url, true)
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

   local path = pkg.."/"..version
   local result = {}
   for item, _ in pairs(itemsfn(pkg, version)) do
      table.insert(result, item)
      if not tbl[item] then
         tbl[item] = {}
      end
      table.insert(tbl[item], path)
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

   local filename = fs.make_path(repo, "manifest")
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
      for version, repos in pairs(versions) do
         local versiontable = {}
         for _, repo in ipairs(repos) do
            local repotable = {}
            repotable.arch = repo.arch
            if repo.arch == "installed" then
               repotable.modules = store_package_items(rep.package_modules, pkg, version, manifest.modules)
               repotable.commands = store_package_items(rep.package_commands, pkg, version, manifest.commands)
            end
            table.insert(versiontable, repotable)
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
   manifest_cache[repo] = manifest
   store_results(results, manifest)
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
<font size="-1"><a href="$original">latest sources</a> | <a href="$homepage">project homepage</a> | License: $license</font></p>
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
   files = fs.find(repo)
   local out = io.open(fs.make_path(repo, "index.html"), "w")
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
         local rockspec = persist.load_into_table(fs.make_path(repo, latest_rockspec))
         local vars = {
            anchor = package,
            package = rockspec.package,
            original = rockspec.source.url,
            summary = rockspec.description.summary or "",
            detailed = rockspec.description.detailed or "",
            license = rockspec.description.license or "N/A",
            homepage = rockspec.description.homepage or ""
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

