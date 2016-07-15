--- Module for handling manifest files and tables.
-- Manifest files describe the contents of a LuaRocks tree or server.
-- They are loaded into manifest tables, which are then used for
-- performing searches, matching dependencies, etc.
local manif = {}
setmetatable(manif, { __index = require("luarocks.core.manif") })

local persist = require("luarocks.persist")
local fetch = require("luarocks.fetch")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")
local path = require("luarocks.path")

manif.rock_manifest_cache = {}

function manif.load_rock_manifest(name, version, root)
   assert(type(name) == "string")
   assert(type(version) == "string")

   local name_version = name.."/"..version
   if manif.rock_manifest_cache[name_version] then
      return manif.rock_manifest_cache[name_version].rock_manifest
   end
   local pathname = path.rock_manifest_file(name, version, root)
   local rock_manifest = persist.load_into_table(pathname)
   if not rock_manifest then return nil end
   manif.rock_manifest_cache[name_version] = rock_manifest
   return rock_manifest.rock_manifest
end

local function fetch_manifest_from(repo_url, filename)
   local url = dir.path(repo_url, filename)
   local name = repo_url:gsub("[/:]","_")
   local cache_dir = dir.path(cfg.local_cache, name)
   local ok = fs.make_dir(cache_dir)
   if not ok then
      return nil, "Failed creating temporary cache directory "..cache_dir
   end
   local file, err, errcode = fetch.fetch_url(url, dir.path(cache_dir, filename), true)
   if not file then
      return nil, "Failed fetching manifest for "..repo_url..(err and " - "..err or ""), errcode
   end
   return file
end

--- Load a local or remote manifest describing a repository.
-- All functions that use manifest tables assume they were obtained
-- through either this function or load_local_manifest.
-- @param repo_url string: URL or pathname for the repository.
-- @param lua_version string: Lua version in "5.x" format, defaults to installed version.
-- @return table or (nil, string, [string]): A table representing the manifest,
-- or nil followed by an error message and an optional error code.
function manif.load_manifest(repo_url, lua_version)
   assert(type(repo_url) == "string")
   assert(type(lua_version) == "string" or not lua_version)
   lua_version = lua_version or cfg.lua_version

   local cached_manifest = manif.get_cached_manifest(repo_url, lua_version)
   if cached_manifest then
      return cached_manifest
   end

   local filenames = {
      "manifest-"..lua_version..".zip",
      "manifest-"..lua_version,
      "manifest",
   }

   local protocol, repodir = dir.split_url(repo_url)
   local pathname
   if protocol == "file" then
      for _, filename in ipairs(filenames) do
         pathname = dir.path(repodir, filename)
         if fs.exists(pathname) then
            break
         end
      end
   else
      local err, errcode
      for _, filename in ipairs(filenames) do
         pathname, err, errcode = fetch_manifest_from(repo_url, filename)
         if pathname then
            break
         end
      end
      if not pathname then 
         return nil, err, errcode
      end
   end
   if pathname:match(".*%.zip$") then
      pathname = fs.absolute_name(pathname)
      local dir = dir.dir_name(pathname)
      fs.change_dir(dir)
      local nozip = pathname:match("(.*)%.zip$")
      fs.delete(nozip)
      local ok = fs.unzip(pathname)
      fs.pop_dir()
      if not ok then
         fs.delete(pathname)
         fs.delete(pathname..".timestamp")
         return nil, "Failed extracting manifest file"
      end
      pathname = nozip
   end
   return manif.manifest_loader(pathname, repo_url, lua_version)
end

local function find_providers(file, root)
   assert(type(file) == "string")
   root = root or cfg.root_dir

   local manifest, err = manif.load_local_manifest(path.rocks_dir(root))
   if not manifest then
      return nil, "untracked"
   end
   local deploy_bin = path.deploy_bin_dir(root)
   local deploy_lua = path.deploy_lua_dir(root)
   local deploy_lib = path.deploy_lib_dir(root)
   local key, manifest_tbl

   if util.starts_with(file, deploy_lua) then
      manifest_tbl = manifest.modules
      key = path.path_to_module(file:sub(#deploy_lua+1):gsub("\\", "/"))
   elseif util.starts_with(file, deploy_lib) then
      manifest_tbl = manifest.modules
      key = path.path_to_module(file:sub(#deploy_lib+1):gsub("\\", "/"))
   elseif util.starts_with(file, deploy_bin) then
      manifest_tbl = manifest.commands
      key = file:sub(#deploy_bin+1):gsub("^[\\/]*", "")
   else
      assert(false, "Assertion failed: '"..file.."' is not a deployed file.")
   end

   local providers = manifest_tbl[key]
   if not providers then
      return nil, "untracked"
   end
   return providers
end

--- Given a path of a deployed file, figure out which rock name and version
-- correspond to it in the tree manifest.
-- @param file string: The full path of a deployed file.
-- @param root string or nil: A local root dir for a rocks tree. If not given, the default is used.
-- @return string, string: name and version of the provider rock.
function manif.find_current_provider(file, root)
   local providers, err = find_providers(file, root)
   if not providers then return nil, err end
   return providers[1]:match("([^/]*)/([^/]*)")
end

function manif.find_next_provider(file, root)
   local providers, err = find_providers(file, root)
   if not providers then return nil, err end
   if providers[2] then
      return providers[2]:match("([^/]*)/([^/]*)")
   else
      return nil
   end
end

return manif
