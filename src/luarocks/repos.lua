
--- Functions for managing the repository on disk.
--module("luarocks.repos", package.seeall)
local repos = {}
package.loaded["luarocks.repos"] = repos

local fs = require("luarocks.fs")
local path = require("luarocks.path")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")
local deps = require("luarocks.deps")

--- Get all installed versions of a package.
-- @param name string: a package name.
-- @return table or nil: An array of strings listing installed
-- versions of a package, or nil if none is available.
local function get_installed_versions(name)
   assert(type(name) == "string")
   
   local dirs = fs.list_dir(path.versions_dir(name))
   return (dirs and #dirs > 0) and dirs or nil
end

--- Check if a package exists in a local repository.
-- Version numbers are compared as exact string comparison.
-- @param name string: name of package
-- @param version string: package version in string format
-- @return boolean: true if a package is installed,
-- false otherwise.
function repos.is_installed(name, version)
   assert(type(name) == "string")
   assert(type(version) == "string")
      
   return fs.is_dir(path.install_dir(name, version))
end

local function recurse_rock_manifest_tree(file_tree, action) 
   assert(type(file_tree) == "table")
   assert(type(action) == "function")
   local function do_recurse_rock_manifest_tree(tree, parent_path, parent_module)
      
      for file, sub in pairs(tree) do
         if type(sub) == "table" then
            local ok, err = do_recurse_rock_manifest_tree(sub, parent_path..file.."/", parent_module..file..".")
            if not ok then return nil, err end
         else
            local ok, err = action(parent_path, parent_module, file)
            if not ok then return nil, err end
         end
      end
      return true
   end
   return do_recurse_rock_manifest_tree(file_tree, "", "")
end

local function store_package_data(result, name, file_tree)
   if not file_tree then return end
   return recurse_rock_manifest_tree(file_tree, 
      function(parent_path, parent_module, file)
         local pathname = parent_path..file
         result[path.path_to_module(pathname)] = pathname
         return true
      end
   )
end

--- Obtain a list of modules within an installed package.
-- @param package string: The package name; for example "luasocket"
-- @param version string: The exact version number including revision;
-- for example "2.0.1-1".
-- @return table: A table of modules where keys are module identifiers
-- in "foo.bar" format and values are pathnames in architecture-dependent
-- "foo/bar.so" format. If no modules are found or if package or version
-- are invalid, an empty table is returned.
function repos.package_modules(package, version)
   assert(type(package) == "string")
   assert(type(version) == "string")

   local result = {}
   local rock_manifest = manif.load_rock_manifest(package, version)
   store_package_data(result, package, rock_manifest.lib)
   store_package_data(result, package, rock_manifest.lua)
   return result
end

--- Obtain a list of command-line scripts within an installed package.
-- @param package string: The package name; for example "luasocket"
-- @param version string: The exact version number including revision;
-- for example "2.0.1-1".
-- @return table: A table of items where keys are command names
-- as strings and values are pathnames in architecture-dependent
-- ".../bin/foo" format. If no modules are found or if package or version
-- are invalid, an empty table is returned.
function repos.package_commands(package, version)
   assert(type(package) == "string")
   assert(type(version) == "string")

   local result = {}
   local rock_manifest = manif.load_rock_manifest(package, version)
   store_package_data(result, package, rock_manifest.bin)
   return result
end


--- Check if a rock contains binary executables.
-- @param name string: name of an installed rock
-- @param version string: version of an installed rock
-- @return boolean: returns true if rock contains platform-specific
-- binary executables, or false if it is a pure-Lua rock.
function repos.has_binaries(name, version)
   assert(type(name) == "string")
   assert(type(version) == "string")

   local rock_manifest = manif.load_rock_manifest(name, version)
   if rock_manifest.bin then
      for name, md5 in pairs(rock_manifest.bin) do
         -- TODO verify that it is the same file. If it isn't, find the actual command.
         if fs.is_actual_binary(dir.path(cfg.deploy_bin_dir, name)) then
            return true
         end
      end
   end
   return false
end

function repos.run_hook(rockspec, hook_name)
   assert(type(rockspec) == "table")
   assert(type(hook_name) == "string")

   local hooks = rockspec.hooks
   if not hooks then
      return true
   end
   
   if cfg.hooks_enabled == false then
      return nil, "This rockspec contains hooks, which are blocked by the 'hooks_enabled' setting in your LuaRocks configuration."
   end
   
   if not hooks.substituted_variables then
      util.variable_substitutions(hooks, rockspec.variables)
      hooks.substituted_variables = true
   end
   local hook = hooks[hook_name]
   if hook then
      util.printout(hook)
      if not fs.execute(hook) then
         return nil, "Failed running "..hook_name.." hook."
      end
   end
   return true
end

local function install_binary(source, target, name, version)
   assert(type(source) == "string")
   assert(type(target) == "string")
   
   if fs.is_lua(source) then
      repos.ok, repos.err = fs.wrap_script(source, target, name, version)
   else
      repos.ok, repos.err = fs.copy_binary(source, target)
   end
   return repos.ok, repos.err
end

local function resolve_conflict(target, deploy_dir, name, version)
   local cname, cversion = manif.find_current_provider(target)
   if not cname then
      return nil, cversion
   end
   if name ~= cname or deps.compare_versions(version, cversion) then
      local versioned = path.versioned_name(target, deploy_dir, cname, cversion)
      local ok, err = fs.make_dir(dir.dir_name(versioned))
      if not ok then return nil, err end
      fs.move(target, versioned)
      return target
   else
      return path.versioned_name(target, deploy_dir, name, version)
   end
end

function repos.should_wrap_bin_scripts(rockspec)
   assert(type(rockspec) == "table")

   if cfg.wrap_bin_scripts ~= nil then
      return cfg.wrap_bin_scripts
   end
   if rockspec.deploy and rockspec.deploy.wrap_bin_scripts == false then
      return false
   end
   return true
end

function repos.deploy_files(name, version, wrap_bin_scripts)
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(wrap_bin_scripts) == "boolean")

   local function deploy_file_tree(file_tree, path_fn, deploy_dir, move_fn)
      local source_dir = path_fn(name, version)
      if not move_fn then
         move_fn = fs.move
      end
      return recurse_rock_manifest_tree(file_tree, 
         function(parent_path, parent_module, file)
            local source = dir.path(source_dir, parent_path, file)
            local target = dir.path(deploy_dir, parent_path, file)
            local ok, err
            if fs.exists(target) then
               local new_target, err = resolve_conflict(target, deploy_dir, name, version)
               if err == "untracked" then
                  local backup = target
                  repeat
                     backup = backup.."~"
                  until not fs.exists(backup) -- slight race condition here, but shouldn't be a problem.
                  util.printerr("Warning: "..target.." is not tracked by this installation of LuaRocks. Moving it to "..backup)
                  fs.move(target, backup)
               elseif err then
                  return nil, err.." Cannot install new version."
               else
                  target = new_target
               end
            end
            ok, err = fs.make_dir(dir.dir_name(target))
            if not ok then return nil, err end
            ok, err = move_fn(source, target, name, version)
            fs.remove_dir_tree_if_empty(dir.dir_name(source))
            if not ok then return nil, err end
            return true
         end
      )
   end

   local rock_manifest = manif.load_rock_manifest(name, version)
   
   local ok, err = true
   if rock_manifest.bin then
      local move_bin_fn = wrap_bin_scripts and install_binary or fs.copy_binary
      ok, err = deploy_file_tree(rock_manifest.bin, path.bin_dir, cfg.deploy_bin_dir, move_bin_fn)
   end
   if ok and rock_manifest.lua then
      ok, err = deploy_file_tree(rock_manifest.lua, path.lua_dir, cfg.deploy_lua_dir)
   end
   if ok and rock_manifest.lib then
      ok, err = deploy_file_tree(rock_manifest.lib, path.lib_dir, cfg.deploy_lib_dir)
   end
   return ok, err
end

local function delete_suffixed(filename, suffix)
   local filenames = { filename }
   if suffix and suffix ~= "" then filenames = { filename..suffix, filename } end
   for _, name in ipairs(filenames) do
      if fs.exists(name) then
         fs.delete(name)
         if fs.exists(name) then
            return nil, "Failed deleting "..name, "fail"
         end
         return true, name
      end
   end
   return false, "File not found", "not found"
end

--- Delete a package from the local repository.
-- Version numbers are compared as exact string comparison.
-- @param name string: name of package
-- @param version string: package version in string format
-- @param quick boolean: do not try to fix the versioned name
-- of another version that provides the same module that
-- was deleted. This is used during 'purge', as every module
-- will be eventually deleted.
function repos.delete_version(name, version, quick)
   assert(type(name) == "string")
   assert(type(version) == "string")

   local function delete_deployed_file_tree(file_tree, deploy_dir, suffix)
      return recurse_rock_manifest_tree(file_tree, 
         function(parent_path, parent_module, file)
            local target = dir.path(deploy_dir, parent_path, file)
            local versioned = path.versioned_name(target, deploy_dir, name, version)
            local ok, name, err = delete_suffixed(versioned, suffix)
            if ok then
               fs.remove_dir_tree_if_empty(dir.dir_name(versioned))
               return true
            end
            if err == "fail" then return nil, name end
            ok, name, err = delete_suffixed(target, suffix)
            if err == "fail" then return nil, name end
            if not quick then
               local next_name, next_version = manif.find_next_provider(target)
               if next_name then
                  local versioned = path.versioned_name(name, deploy_dir, next_name, next_version)
                  fs.move(versioned, name)
                  fs.remove_dir_tree_if_empty(dir.dir_name(versioned))
               end
            end
            fs.remove_dir_tree_if_empty(dir.dir_name(target))
            return true
         end
      )
   end

   local rock_manifest = manif.load_rock_manifest(name, version)
   if not rock_manifest then
      return nil, "rock_manifest file not found for "..name.." "..version.." - not a LuaRocks 2 tree?"
   end
   
   local ok, err = true
   if rock_manifest.bin then
      ok, err = delete_deployed_file_tree(rock_manifest.bin, cfg.deploy_bin_dir, cfg.wrapper_suffix)
   end
   if ok and rock_manifest.lua then
      ok, err = delete_deployed_file_tree(rock_manifest.lua, cfg.deploy_lua_dir)
   end
   if ok and rock_manifest.lib then
      ok, err = delete_deployed_file_tree(rock_manifest.lib, cfg.deploy_lib_dir)
   end
   if err then return nil, err end

   fs.delete(path.install_dir(name, version))
   if not get_installed_versions(name) then
      fs.delete(dir.path(cfg.rocks_dir, name))
   end
   return true
end

return repos
