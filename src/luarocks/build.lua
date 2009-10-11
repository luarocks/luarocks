
--- Module implementing the LuaRocks "build" command.
-- Builds a rock, compiling its C parts if any.
module("luarocks.build", package.seeall)

local path = require("luarocks.path")
local util = require("luarocks.util")
local rep = require("luarocks.rep")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")
local manif = require("luarocks.manif")

help_summary = "Build/compile a rock."
help_arguments = "{<rockspec>|<rock>|<name> [<version>]}"
help = [[
Build a rock, compiling its C parts if any.
Argument may be a rockspec file, a source rock file
or the name of a rock to be fetched from a repository.
]]

--- Install files to a given location.
-- Takes a table where the array part is a list of filenames to be copied.
-- In the hash part, other keys are identifiers in Lua module format,
-- to indicate which subdirectory the file should be copied to. For example,
-- install_files({["foo.bar"] = "src/bar.lua"}, "boo") will copy src/bar.lua
-- to boo/foo.
-- @param files table or nil: A table containing a list of files to copy in
-- the format described above. If nil is passed, this function is a no-op.
-- Directories should be delimited by forward slashes as in internet URLs.
-- @param location string: The base directory files should be copied to.
-- @return boolean or (nil, string): True if succeeded or 
-- nil and an error message.
local function install_files(files, location) 
   assert(type(files) == "table" or not files)
   assert(type(location) == "string")
   if files then
      for k, file in pairs(files) do
         local dest = location
         if type(k) == "string" then
            dest = dir.path(location, path.module_to_path(k))
         end
         fs.make_dir(dest)
         local ok = fs.copy(dir.path(file), dest)
         if not ok then
            return nil, "Failed copying "..file
         end
      end
   end
   return true
end

--- Write to the current directory the contents of a table,
-- where each key is a file name and its value is the file content.
-- @param files table: The table of files to be written.
local function extract_from_rockspec(files)
   for name, content in pairs(files) do
      local fd = io.open(dir.path(fs.current_dir(), name), "w+")
      fd:write(content)
      fd:close()
   end
end

--- Applies patches inlined in the build.patches section
-- and extracts files inlined in the build.extra_files section
-- of a rockspec. 
-- @param rockspec table: A rockspec table.
-- @return boolean or (nil, string): True if succeeded or 
-- nil and an error message.
function apply_patches(rockspec)
   assert(type(rockspec) == "table")

   local build = rockspec.build
   if build.extra_files then
      extract_from_rockspec(build.extra_files)
   end
   if build.patches then
      extract_from_rockspec(build.patches)
      for patch, patchdata in util.sortedpairs(build.patches) do
         print("Applying patch "..patch.."...")
         local ok, err = fs.apply_patch(tostring(patch), patchdata)
         if not ok then
            return nil, "Failed applying patch "..patch
         end
      end
   end
   return true
end

--- Build and install a rock given a rockspec.
-- @param rockspec_file string: local or remote filename of a rockspec.
-- @param need_to_fetch boolean: true if sources need to be fetched,
-- false if the rockspec was obtained from inside a source rock.
-- @return boolean or (nil, string, [string]): True if succeeded or 
-- nil and an error message followed by an error code.
function build_rockspec(rockspec_file, need_to_fetch, minimal_mode)
   assert(type(rockspec_file) == "string")
   assert(type(need_to_fetch) == "boolean")

   local rockspec, err, errcode = fetch.load_rockspec(rockspec_file)
   if err then
      return nil, err, errcode
   elseif not rockspec.build then
      return nil, "Rockspec error: build table not specified"
   elseif not rockspec.build.type then
      return nil, "Rockspec error: build type not specified"
   end

   local ok, err, errcode = deps.fulfill_dependencies(rockspec)
   if err then
      return nil, err, errcode
   end
   ok, err, errcode = deps.check_external_deps(rockspec, "build")
   if err then
      return nil, err, errcode
   end

   local name, version = rockspec.name, rockspec.version
   if rep.is_installed(name, version) then
      rep.delete_version(name, version)
   end

   if not minimal_mode then
      local _, source_dir
      if need_to_fetch then
         ok, source_dir, errcode = fetch.fetch_sources(rockspec, true)
         if not ok then
            return nil, source_dir, errcode
         end
         fs.change_dir(source_dir)
      elseif rockspec.source.file then
         local ok, err = fs.unpack_archive(rockspec.source.file)
         if not ok then
            return nil, err
         end
      end
      fs.change_dir(rockspec.source.dir)
   end
   
   local dirs = {
      lua = path.lua_dir(name, version),
      lib = path.lib_dir(name, version),
      conf = path.conf_dir(name, version),
      bin = path.bin_dir(name, version),
   }
   
   for _, d in pairs(dirs) do
      fs.make_dir(d)
   end
   local rollback = util.schedule_function(function()
      fs.delete(path.install_dir(name, version))
      fs.remove_dir_if_empty(path.versions_dir(name))
   end)

   local build = rockspec.build
   
   if not minimal_mode then
      ok, err = apply_patches(rockspec)
      if err then
         return nil, err
      end
   end
   
   if build.type ~= "none" then

      -- Temporary compatibility
      if build.type == "module" then
         print("Do not use 'module' as a build type. Use 'builtin' instead.")
         build.type = "builtin"
      end

      local build_type
      ok, build_type = pcall(require, "luarocks.build." .. build.type)
      if not ok or not type(build_type) == "table" then
         return nil, "Failed initializing build back-end for build type '"..build.type.."'"
      end
  
      ok, err = build_type.run(rockspec)
      if not ok then
         return nil, "Build error: " .. err
      end
   end

   if build.install then
      for id, install_dir in pairs(dirs) do
         ok, err = install_files(build.install[id], install_dir)
         if not ok then 
            return nil, err
         end
      end
   end
   
   local copy_directories = build.copy_directories or {"doc"}

   for _, copy_dir in pairs(copy_directories) do
      if fs.is_dir(copy_dir) then
         local dest = dir.path(path.install_dir(name, version), copy_dir)
         fs.make_dir(dest)
         fs.copy_contents(copy_dir, dest)
      end
   end

   for _, d in pairs(dirs) do
      fs.remove_dir_if_empty(d)
   end

   fs.pop_dir()
   
   fs.copy(rockspec.local_filename, path.rockspec_file(name, version))
   if need_to_fetch then
      fs.pop_dir()
   end

   ok, err = manif.make_rock_manifest(name, version)
   if err then return nil, err end

   ok, err = rep.deploy_files(name, version)
   if err then return nil, err end
   
   util.remove_scheduled_function(rollback)
   rollback = util.schedule_function(function()
      rep.delete_version(name, version)
   end)

   ok, err = rep.run_hook(rockspec, "post_install")
   if err then return nil, err end

   ok, err = manif.update_manifest(name, version)
   if err then return nil, err end

   util.remove_scheduled_function(rollback)
   return true
end

--- Build and install a rock.
-- @param rock_file string: local or remote filename of a rock.
-- @param need_to_fetch boolean: true if sources need to be fetched,
-- false if the rockspec was obtained from inside a source rock.
-- @return boolean or (nil, string, [string]): True if build was successful,
-- or false and an error message and an optional error code.
function build_rock(rock_file, need_to_fetch)
   assert(type(rock_file) == "string")
   assert(type(need_to_fetch) == "boolean")
  
   local unpack_dir, err, errcode = fetch.fetch_and_unpack_rock(rock_file)
   if not unpack_dir then
      return nil, err, errcode
   end
   local rockspec_file = path.rockspec_name_from_rock(rock_file)
   fs.change_dir(unpack_dir)
   local ok, err, errcode = build_rockspec(rockspec_file, need_to_fetch)
   fs.pop_dir()
   return ok, err, errcode
end

--- Driver function for "build" command.
-- @param name string: A local or remote rockspec or rock file.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number may
-- also be given.
-- @return boolean or (nil, string): True if build was successful; nil and an
-- error message otherwise.
function run(...)
   local flags, name, version = util.parse_flags(...)
   if type(name) ~= "string" then
      return nil, "Argument missing, see help."
   end
   assert(type(version) == "string" or not version)

   if name:match("%.rockspec$") then
      return build_rockspec(name, true)
   elseif name:match("%.src%.rock$") then
      return build_rock(name, false)
   elseif name:match("%.all%.rock$") then
      local install = require("luarocks.install")
      return install.install_binary_rock(name)
   elseif name:match("%.rock$") then
      return build_rock(name, true)
   elseif not name:match(dir.separator) then
      local search = require("luarocks.search")
      return search.act_on_src_or_rockspec(run, name, version)
   end
   return nil, "Don't know what to do with "..name
end
