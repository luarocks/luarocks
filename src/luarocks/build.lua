
local build = {}

local path = require("luarocks.path")
local util = require("luarocks.util")
local fun = require("luarocks.fun")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")
local cfg = require("luarocks.core.cfg")
local repos = require("luarocks.repos")
local writer = require("luarocks.manif.writer")

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
         local create_delete = rockspec:format_is_at_least("3.0")
         local ok, err = fs.apply_patch(tostring(patch), patchdata, create_delete)
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

local function check_macosx_deployment_target(rockspec)
   local target = rockspec.build.macosx_deployment_target
   local function minor(version) 
      return tonumber(version and version:match("^[^.]+%.([^.]+)"))
   end
   local function patch_variable(var, target)
      if rockspec.variables[var]:match("MACOSX_DEPLOYMENT_TARGET") then
         rockspec.variables[var] = (rockspec.variables[var]):gsub("MACOSX_DEPLOYMENT_TARGET=[^ ]*", "MACOSX_DEPLOYMENT_TARGET="..target)
      else
         rockspec.variables[var] = "env MACOSX_DEPLOYMENT_TARGET="..target.." "..rockspec.variables[var]
      end
   end
   if cfg.platforms.macosx and rockspec:format_is_at_least("3.0") and target then
      local version = util.popen_read("sw_vers -productVersion")
      local versionminor = minor(version)
      local targetminor = minor(target)
      if targetminor > versionminor then
         return nil, ("This rock requires Mac OSX 10.%d, and you are running 10.%d."):format(targetminor, versionminor)
      end
      patch_variable("CC", target)
      patch_variable("LD", target)
   end
   return true
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
-- @param namespace string?: a namespace for the rockspec
-- @return (string, string) or (nil, string, [string]): Name and version of
-- installed rock if succeeded or nil and an error message followed by an error code.
function build.build_rockspec(rockspec_file, need_to_fetch, minimal_mode, deps_mode, build_only_deps, namespace)
   assert(type(rockspec_file) == "string")
   assert(type(need_to_fetch) == "boolean")
   assert(type(namespace) == "string" or not namespace)

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
      util.warning("skipping dependency checks.")
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
   
   ok, err = check_macosx_deployment_target(rockspec)
   if not ok then
      return nil, err
   end
   
   if build_spec.type ~= "none" then

      -- Temporary compatibility
      if build_spec.type == "module" then
         util.printout("Do not use 'module' as a build type. Use 'builtin' instead.")
         build_spec.type = "builtin"
      end

      if cfg.accepted_build_types and fun.contains(cfg.accepted_build_types, build_spec.type) then
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

   ok, err = writer.make_rock_manifest(name, version)
   if err then return nil, err end

   ok, err = writer.make_namespace_file(name, version, namespace)
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

return build
