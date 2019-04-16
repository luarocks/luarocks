
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

build.opts = util.opts_table("build.opts", {
   need_to_fetch = "boolean",
   minimal_mode = "boolean",
   deps_mode = "string",
   build_only_deps = "boolean",
   namespace = "string?",
   branch = "boolean",
   verify = "boolean",
})

do
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
      assert(rockspec:type() == "rockspec")

      if not (rockspec.build.extra_files or rockspec.build.patches) then
         return true
      end

      local fd = io.open(fs.absolute_name(".luarocks.patches.applied"), "r")
      if fd then
         fd:close()
         return true
      end

      if rockspec.build.extra_files then
         extract_from_rockspec(rockspec.build.extra_files)
      end
      if rockspec.build.patches then
         extract_from_rockspec(rockspec.build.patches)
         for patch, patchdata in util.sortedpairs(rockspec.build.patches) do
            util.printout("Applying patch "..patch.."...")
            local create_delete = rockspec:format_is_at_least("3.0")
            local ok, err = fs.apply_patch(tostring(patch), patchdata, create_delete)
            if not ok then
               return nil, "Failed applying patch "..patch
            end
         end
      end

      fd = io.open(fs.absolute_name(".luarocks.patches.applied"), "w")
      if fd then
         fd:close()
      end
      return true
   end
end

local function check_macosx_deployment_target(rockspec)
   local target = rockspec.build.macosx_deployment_target
   local function minor(version) 
      return tonumber(version and version:match("^[^.]+%.([^.]+)"))
   end
   local function patch_variable(var)
      if rockspec.variables[var]:match("MACOSX_DEPLOYMENT_TARGET") then
         rockspec.variables[var] = (rockspec.variables[var]):gsub("MACOSX_DEPLOYMENT_TARGET=[^ ]*", "MACOSX_DEPLOYMENT_TARGET="..target)
      else
         rockspec.variables[var] = "env MACOSX_DEPLOYMENT_TARGET="..target.." "..rockspec.variables[var]
      end
   end
   if cfg.is_platform("macosx") and rockspec:format_is_at_least("3.0") and target then
      local version = util.popen_read("sw_vers -productVersion")
      local versionminor = minor(version)
      local targetminor = minor(target)
      if targetminor > versionminor then
         return nil, ("This rock requires Mac OSX 10.%d, and you are running 10.%d."):format(targetminor, versionminor)
      end
      patch_variable("CC")
      patch_variable("LD")
   end
   return true
end

local function process_dependencies(rockspec, opts)
   if not opts.build_only_deps then
      local ok, err, errcode = deps.check_external_deps(rockspec, "build")
      if err then
         return nil, err, errcode
      end
   end

   local ok, err, errcode = deps.check_lua(rockspec.variables)
   if not ok then
      return nil, err, errcode
   end

   if opts.deps_mode == "none" then
      util.warning("skipping dependency checks.")
      return true
   end
   if not opts.build_only_deps then
      if next(rockspec.build_dependencies) then
         local ok, err, errcode = deps.fulfill_dependencies(rockspec, "build_dependencies", opts.deps_mode, opts.verify)
         if err then
            return nil, err, errcode
         end
      end
   end
   local ok, err, errcode = deps.fulfill_dependencies(rockspec, "dependencies", opts.deps_mode, opts.verify)
   if err then
      return nil, err, errcode
   end
   return true
end

local function fetch_and_change_to_source_dir(rockspec, opts)
   if opts.minimal_mode then
      return true
   end
   if opts.need_to_fetch then
      if opts.branch then
         rockspec.source.branch = opts.branch
      end
      local ok, source_dir, errcode = fetch.fetch_sources(rockspec, true)
      if not ok then
         return nil, source_dir, errcode
      end
      local err
      ok, err = fs.change_dir(source_dir)
      if not ok then
         return nil, err
      end
   elseif rockspec.source.file then
      local ok, err = fs.unpack_archive(rockspec.source.file)
      if not ok then
         return nil, err
      end
   end
   fs.change_dir(rockspec.source.dir)
   return true
end

local function prepare_install_dirs(name, version)
   local dirs = {
      lua = { name = path.lua_dir(name, version), is_module_path = true, perms = "read" },
      lib = { name = path.lib_dir(name, version), is_module_path = true, perms = "exec" },
      bin = { name = path.bin_dir(name, version), is_module_path = false, perms = "exec" },
      conf = { name = path.conf_dir(name, version), is_module_path = false, perms = "read" },
   }

   for _, d in pairs(dirs) do
      local ok, err = fs.make_dir(d.name)
      if not ok then
         return nil, err
      end
   end

   return dirs
end

local function run_build_driver(rockspec)
   local btype = rockspec.build.type
   if btype == "none" then
      return true
   end
   -- Temporary compatibility
   if btype == "module" then
      util.printout("Do not use 'module' as a build type. Use 'builtin' instead.")
      btype = "builtin"
      rockspec.build.type = btype
   end
   if cfg.accepted_build_types and not fun.contains(cfg.accepted_build_types, btype) then
      return nil, "This rockspec uses the '"..btype.."' build type, which is blocked by the 'accepted_build_types' setting in your LuaRocks configuration."
   end
   local pok, driver = pcall(require, "luarocks.build." .. btype)
   if not pok or type(driver) ~= "table" then
      return nil, "Failed initializing build back-end for build type '"..btype.."': "..driver
   end
   local ok, err = driver.run(rockspec)
   if not ok then
      return nil, "Build error: " .. err
   end
   return true
end

local install_files
do
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
   -- @param perms string ("read" or "exec"): Permissions of the newly created
   -- files installed.
   -- Directories are always created with the default permissions.
   -- @return boolean or (nil, string): True if succeeded or
   -- nil and an error message.
   local function install_to(files, location, is_module_path, perms)
      assert(type(files) == "table" or not files)
      assert(type(location) == "string")
      if not files then
         return true
      end
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
               fs.copy(file, dest, "read")
               break
            end
         end
      end
   end

   install_files = function(rockspec, dirs)
      local name, version = rockspec.name, rockspec.version

      if rockspec.build.install then
         for k, d in pairs(dirs) do
            local ok, err = install_to(rockspec.build.install[k], d.name, d.is_module_path, d.perms)
            if not ok then return nil, err end
         end
      end

      local copy_directories = rockspec.build.copy_directories
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

      return true
   end
end

local function write_rock_dir_files(rockspec, opts)
   local name, version = rockspec.name, rockspec.version

   fs.copy(rockspec.local_abs_filename, path.rockspec_file(name, version), "read")

   local ok, err = writer.make_rock_manifest(name, version)
   if not ok then return nil, err end

   ok, err = writer.make_namespace_file(name, version, opts.namespace)
   if not ok then return nil, err end

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
-- @param branch string?: a forced branch to use
-- @return (string, string) or (nil, string, [string]): Name and version of
-- installed rock if succeeded or nil and an error message followed by an error code.
function build.build_rockspec(rockspec, opts)
   assert(rockspec:type() == "rockspec")
   assert(opts:type() == "build.opts")

   if not rockspec.build then
      if rockspec:format_is_at_least("3.0") then
         rockspec.build = {
            type = "builtin"
         }
      else
         return nil, "Rockspec error: build table not specified"
      end
   end

   if not rockspec.build.type then
      if rockspec:format_is_at_least("3.0") then
         rockspec.build.type = "builtin"
      else
         return nil, "Rockspec error: build type not specified"
      end
   end

   local ok, err = process_dependencies(rockspec, opts)
   if not ok then return nil, err end

   local name, version = rockspec.name, rockspec.version
   if opts.build_only_deps then
      return name, version
   end   

   if repos.is_installed(name, version) then
      repos.delete_version(name, version, opts.deps_mode)
   end

   ok, err = fetch_and_change_to_source_dir(rockspec, opts)
   if not ok then return nil, err end
   
   local dirs, err = prepare_install_dirs(name, version)
   if not dirs then return nil, err end
   
   local rollback = util.schedule_function(function()
      fs.delete(path.install_dir(name, version))
      fs.remove_dir_if_empty(path.versions_dir(name))
   end)

   ok, err = build.apply_patches(rockspec)
   if not ok then return nil, err end
   
   ok, err = check_macosx_deployment_target(rockspec)
   if not ok then return nil, err end
   
   ok, err = run_build_driver(rockspec)
   if not ok then return nil, err end
   
   ok, err = install_files(rockspec, dirs)
   if not ok then return nil, err end
   
   for _, d in pairs(dirs) do
      fs.remove_dir_if_empty(d.name)
   end

   fs.pop_dir()
   if opts.need_to_fetch then
      fs.pop_dir()
   end

   ok, err = write_rock_dir_files(rockspec, opts)
   if not ok then return nil, err end

   ok, err = repos.deploy_files(name, version, repos.should_wrap_bin_scripts(rockspec), opts.deps_mode)
   if not ok then return nil, err end
   
   util.remove_scheduled_function(rollback)
   rollback = util.schedule_function(function()
      repos.delete_version(name, version, opts.deps_mode)
   end)

   ok, err = repos.run_hook(rockspec, "post_install")
   if not ok then return nil, err end

   util.announce_install(rockspec)
   util.remove_scheduled_function(rollback)
   return name, version
end

return build
