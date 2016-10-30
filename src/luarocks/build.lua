
--- Module implementing the LuaRocks "build" command.
-- Builds a rock, compiling its C parts if any.
local build = {}
package.loaded["luarocks.build"] = build

local pack = require("luarocks.pack")
local path = require("luarocks.path")
local util = require("luarocks.util")
local repos = require("luarocks.repos")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")
local manif = require("luarocks.manif")
local remove = require("luarocks.remove")
local cfg = require("luarocks.cfg")

util.add_run_function(build)
build.help_summary = "Build/compile a rock."
build.help_arguments = "[--pack-binary-rock] [--keep] {<rockspec>|<rock>|<name> [<version>]}"
build.help = [[
Build and install a rock, compiling its C parts if any.
Argument may be a rockspec file, a source rock file
or the name of a rock to be fetched from a repository.

--pack-binary-rock  Do not install rock. Instead, produce a .rock file
                    with the contents of compilation in the current
                    directory.

--keep              Do not remove previously installed versions of the
                    rock after building a new one. This behavior can
                    be made permanent by setting keep_other_versions=true
                    in the configuration file.

--branch=<name>     Override the `source.branch` field in the loaded
                    rockspec. Allows to specify a different branch to 
                    fetch. Particularly for SCM rocks.

--only-deps         Installs only the dependencies of the rock.

]]..util.deps_mode_help()

--- Install files to a given location.
-- Takes a table where the array part is a list of filenames to be copied.
-- In the hash part, other keys, if is_module_path is set, are identifiers
-- in Lua module format, to indicate which subdirectory the file should be
-- copied to. For example, install_files({["foo.bar"] = "src/bar.lua"}, "boo")
-- will copy src/bar.lua to boo/foo.
-- @param files table or nil: A table containing a list of files to copy in
-- the format described above. If nil is passed, this function is a no-op.
-- Directories should be delimited by forward slashes as in internet URLs.
-- @param location string: The base directory files should be copied to.
-- @param is_module_path boolean: True if string keys in files should be
-- interpreted as dotted module paths.
-- @param perms string: Permissions of the newly created files installed.
-- Directories are always created with the default permissions.
-- @return boolean or (nil, string): True if succeeded or 
-- nil and an error message.
local function install_files(files, location, is_module_path, perms)
   assert(type(files) == "table" or not files)
   assert(type(location) == "string")
   if files then
      for k, file in pairs(files) do
         local dest = location
         local filename = dir.base_name(file)
         if type(k) == "string" then
            local modname = k
            if is_module_path then
               dest = dir.path(location, path.module_to_path(modname))
               local ok, err = fs.make_dir(dest)
               if not ok then return nil, err end
               if filename:match("%.lua$") then
                  local basename = modname:match("([^.]+)$")
                  filename = basename..".lua"
               end
            else
               dest = dir.path(location, dir.dir_name(modname))
               local ok, err = fs.make_dir(dest)
               if not ok then return nil, err end
               filename = dir.base_name(modname)
            end
         else
            local ok, err = fs.make_dir(dest)
            if not ok then return nil, err end
         end
         local ok = fs.copy(dir.path(file), dir.path(dest, filename), perms)
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
function build.apply_patches(rockspec)
   assert(type(rockspec) == "table")

   local build_spec = rockspec.build
   if build_spec.extra_files then
      extract_from_rockspec(build_spec.extra_files)
   end
   if build_spec.patches then
      extract_from_rockspec(build_spec.patches)
      for patch, patchdata in util.sortedpairs(build_spec.patches) do
         util.printout("Applying patch "..patch.."...")
         local ok, err = fs.apply_patch(tostring(patch), patchdata)
         if not ok then
            return nil, "Failed applying patch "..patch
         end
      end
   end
   return true
end

local function install_default_docs(name, version)
   local patterns = { "readme", "license", "copying", ".*%.md" }
   local dest = dir.path(path.install_dir(name, version), "doc")
   local has_dir = false
   for file in fs.dir() do
      for _, pattern in ipairs(patterns) do
         if file:lower():match("^"..pattern) then
            if not has_dir then
               fs.make_dir(dest)
               has_dir = true
            end
            fs.copy(file, dest, cfg.perm_read)
            break
         end
      end
   end
end

--- Build and install a rock given a rockspec.
-- @param rockspec_file string: local or remote filename of a rockspec.
-- @param need_to_fetch boolean: true if sources need to be fetched,
-- false if the rockspec was obtained from inside a source rock.
-- @param minimal_mode boolean: true if there's no need to fetch,
-- unpack or change dir (this is used by "luarocks make"). Implies
-- need_to_fetch = false.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for no trees.
-- @param build_only_deps boolean: true to build the listed dependencies only.
-- @return (string, string) or (nil, string, [string]): Name and version of
-- installed rock if succeeded or nil and an error message followed by an error code.
function build.build_rockspec(rockspec_file, need_to_fetch, minimal_mode, deps_mode, build_only_deps)
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

   local ok
   if not build_only_deps then
      ok, err, errcode = deps.check_external_deps(rockspec, "build")
      if err then
         return nil, err, errcode
      end
   end

   if deps_mode == "none" then
      util.printerr("Warning: skipping dependency checks.")
   else
      local ok, err, errcode = deps.fulfill_dependencies(rockspec, deps_mode)
      if err then
         return nil, err, errcode
      end
   end

   local name, version = rockspec.name, rockspec.version
   if build_only_deps then
      util.printout("Stopping after installing dependencies for " ..name.." "..version)
      util.printout()
      return name, version
   end   

   if repos.is_installed(name, version) then
      repos.delete_version(name, version, deps_mode)
   end

   if not minimal_mode then
      local source_dir
      if need_to_fetch then
         ok, source_dir, errcode = fetch.fetch_sources(rockspec, true)
         if not ok then
            return nil, source_dir, errcode
         end
         local ok, err = fs.change_dir(source_dir)
         if not ok then return nil, err end
      elseif rockspec.source.file then
         local ok, err = fs.unpack_archive(rockspec.source.file)
         if not ok then
            return nil, err
         end
      end
      fs.change_dir(rockspec.source.dir)
   end
   
   local dirs = {
      lua = { name = path.lua_dir(name, version), is_module_path = true, perms = cfg.perm_read },
      lib = { name = path.lib_dir(name, version), is_module_path = true, perms = cfg.perm_exec },
      conf = { name = path.conf_dir(name, version), is_module_path = false, perms = cfg.perm_read },
      bin = { name = path.bin_dir(name, version), is_module_path = false, perms = cfg.perm_exec },
   }
   
   for _, d in pairs(dirs) do
      local ok, err = fs.make_dir(d.name)
      if not ok then return nil, err end
   end
   local rollback = util.schedule_function(function()
      fs.delete(path.install_dir(name, version))
      fs.remove_dir_if_empty(path.versions_dir(name))
   end)

   local build_spec = rockspec.build
   
   if not minimal_mode then
      ok, err = build.apply_patches(rockspec)
      if err then
         return nil, err
      end
   end
   
   if build_spec.type ~= "none" then

      -- Temporary compatibility
      if build_spec.type == "module" then
         util.printout("Do not use 'module' as a build type. Use 'builtin' instead.")
         build_spec.type = "builtin"
      end

      if cfg.accepted_build_types and util.array_contains(cfg.accepted_build_types, build_spec.type) then
         return nil, "This rockspec uses the '"..build_spec.type.."' build type, which is blocked by the 'accepted_build_types' setting in your LuaRocks configuration."
      end

      local build_type
      ok, build_type = pcall(require, "luarocks.build." .. build_spec.type)
      if not ok or not type(build_type) == "table" then
         return nil, "Failed initializing build back-end for build type '"..build_spec.type.."': "..build_type
      end
  
      ok, err = build_type.run(rockspec)
      if not ok then
         return nil, "Build error: " .. err
      end
   end

   if build_spec.install then
      for id, install_dir in pairs(dirs) do
         ok, err = install_files(build_spec.install[id], install_dir.name, install_dir.is_module_path, install_dir.perms)
         if not ok then 
            return nil, err
         end
      end
   end
   
   local copy_directories = build_spec.copy_directories
   local copying_default = false
   if not copy_directories then
      copy_directories = {"doc"}
      copying_default = true
   end

   local any_docs = false
   for _, copy_dir in pairs(copy_directories) do
      if fs.is_dir(copy_dir) then
         local dest = dir.path(path.install_dir(name, version), copy_dir)
         fs.make_dir(dest)
         fs.copy_contents(copy_dir, dest)
         any_docs = true
      else
         if not copying_default then
            return nil, "Directory '"..copy_dir.."' not found"
         end
      end
   end
   
   if not any_docs then
      install_default_docs(name, version)
   end
   
   for _, d in pairs(dirs) do
      fs.remove_dir_if_empty(d.name)
   end

   fs.pop_dir()
   
   fs.copy(rockspec.local_filename, path.rockspec_file(name, version), cfg.perm_read)
   if need_to_fetch then
      fs.pop_dir()
   end

   ok, err = manif.make_rock_manifest(name, version)
   if err then return nil, err end

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

--- Build and install a rock.
-- @param rock_file string: local or remote filename of a rock.
-- @param need_to_fetch boolean: true if sources need to be fetched,
-- false if the rockspec was obtained from inside a source rock.
-- @param deps_mode: string: Which trees to check dependencies for:
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
-- @param build_only_deps boolean: true to build the listed dependencies only.
-- @return boolean or (nil, string, [string]): True if build was successful,
-- or false and an error message and an optional error code.
function build.build_rock(rock_file, need_to_fetch, deps_mode, build_only_deps)
   assert(type(rock_file) == "string")
   assert(type(need_to_fetch) == "boolean")

   local ok, err, errcode
   local unpack_dir
   unpack_dir, err, errcode = fetch.fetch_and_unpack_rock(rock_file)
   if not unpack_dir then
      return nil, err, errcode
   end
   local rockspec_file = path.rockspec_name_from_rock(rock_file)
   ok, err = fs.change_dir(unpack_dir)
   if not ok then return nil, err end
   ok, err, errcode = build.build_rockspec(rockspec_file, need_to_fetch, false, deps_mode, build_only_deps)
   fs.pop_dir()
   return ok, err, errcode
end
 
local function do_build(name, version, deps_mode, build_only_deps)
   if name:match("%.rockspec$") then
      return build.build_rockspec(name, true, false, deps_mode, build_only_deps)
   elseif name:match("%.src%.rock$") then
      return build.build_rock(name, false, deps_mode, build_only_deps)
   elseif name:match("%.all%.rock$") then
      local install = require("luarocks.install")
      local install_fun = build_only_deps and install.install_binary_rock_deps or install.install_binary_rock
      return install_fun(name, deps_mode)
   elseif name:match("%.rock$") then
      return build.build_rock(name, true, deps_mode, build_only_deps)
   elseif not name:match(dir.separator) then
      local search = require("luarocks.search")
      return search.act_on_src_or_rockspec(do_build, name:lower(), version, nil, deps_mode, build_only_deps)
   end
   return nil, "Don't know what to do with "..name
end

--- Driver function for "build" command.
-- @param name string: A local or remote rockspec or rock file.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number may
-- also be given.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function build.command(flags, name, version)
   if type(name) ~= "string" then
      return nil, "Argument missing. "..util.see_help("build")
   end
   assert(type(version) == "string" or not version)

   if flags["pack-binary-rock"] then
      return pack.pack_binary_rock(name, version, do_build, name, version, deps.get_deps_mode(flags))
   else
      local ok, err = fs.check_command_permissions(flags)
      if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end
      ok, err = do_build(name, version, deps.get_deps_mode(flags), flags["only-deps"])
      if not ok then return nil, err end
      name, version = ok, err

      if (not flags["only-deps"]) and (not flags["keep"]) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, flags["force"], flags["force-fast"])
         if not ok then util.printerr(err) end
      end

      manif.check_dependencies(nil, deps.get_deps_mode(flags))
      return name, version
   end
end

return build
