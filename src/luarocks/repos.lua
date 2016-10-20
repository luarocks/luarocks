
--- Functions for managing the repository on disk.
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

local function find_suffixed(file, suffix)
   local filenames = {file}
   if suffix and suffix ~= "" then
      table.insert(filenames, 1, file .. suffix)
   end

   for _, filename in ipairs(filenames) do
      if fs.exists(filename) then
         return filename
      end
   end

   return nil, table.concat(filenames, ", ") .. " not found"
end

local function move_suffixed(from_file, to_file, suffix)
   local suffixed_from_file, err = find_suffixed(from_file, suffix)
   if not suffixed_from_file then
      return nil, "Could not move " .. from_file .. " to " .. to_file .. ": " .. err
   end

   suffix = suffixed_from_file:sub(#from_file + 1)
   local suffixed_to_file = to_file .. suffix
   return fs.move(suffixed_from_file, suffixed_to_file)
end

local function delete_suffixed(file, suffix)
   local suffixed_file, err = find_suffixed(file, suffix)
   if not suffixed_file then
      return nil, "Could not remove " .. file .. ": " .. err, "not found"
   end

   fs.delete(suffixed_file)
   if fs.exists(suffixed_file) then
      return nil, "Failed deleting " .. suffixed_file .. ": file still exists", "fail"
   end

   return true
end

local function resolve_conflict(target, deploy_dir, name, version, cur_name, cur_version, suffix)
   if name < cur_name or (name == cur_name and deps.compare_versions(version, cur_version)) then
      -- New version has priority. Move currently provided version back using versioned name.
      local cur_target = manif.find_conflicting_file(cur_name, cur_version, target)
      local versioned = path.versioned_name(cur_target, deploy_dir, cur_name, cur_version)

      local ok, err = fs.make_dir(dir.dir_name(versioned))
      if not ok then
         return nil, err
      end

      ok, err = move_suffixed(cur_target, versioned, suffix)
      if not ok then
         return nil, err
      end

      return target
   else
      -- Current version has priority, deploy new version using versioned name.
      return path.versioned_name(target, deploy_dir, name, version)
   end
end

--- Deploy a package from the rocks subdirectory.
-- It is maintained that for each module and command the one that is provided
-- by the newest version of the lexicographically smallest package
-- is installed using unversioned name, and other versions use versioned names.
-- @param name string: name of package
-- @param version string: exact package version in string format
-- @param wrap_bin_scripts bool: whether commands written in Lua should be wrapped.
-- @param deps_mode: string: Which trees to check dependencies for:
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
function repos.deploy_files(name, version, wrap_bin_scripts, deps_mode)
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(wrap_bin_scripts) == "boolean")

   local function deploy_file_tree(file_tree, path_fn, deploy_dir, move_fn, suffix)
      local source_dir = path_fn(name, version)
      return recurse_rock_manifest_tree(file_tree, 
         function(parent_path, parent_module, file)
            local source = dir.path(source_dir, parent_path, file)
            local target = dir.path(deploy_dir, parent_path, file)

            local cur_name, cur_version = manif.find_current_provider(target)
            if cur_name then
               local resolve_err
               target, resolve_err = resolve_conflict(target, deploy_dir, name, version, cur_name, cur_version, suffix)
               if not target then
                  return nil, resolve_err
               end
            end

            local ok, err = fs.make_dir(dir.dir_name(target))
            if not ok then return nil, err end

            local suffixed_target, mover = move_fn(source, target, name, version)
            if fs.exists(suffixed_target) then
               local backup = suffixed_target
               repeat
                  backup = backup.."~"
               until not fs.exists(backup) -- Slight race condition here, but shouldn't be a problem.

               util.printerr("Warning: "..suffixed_target.." is not tracked by this installation of LuaRocks. Moving it to "..backup)
               local ok, err = fs.move(suffixed_target, backup)
               if not ok then
                  return nil, err
               end
            end

            ok, err = mover()
            fs.remove_dir_tree_if_empty(dir.dir_name(source))
            return ok, err
         end
      )
   end

   local rock_manifest = manif.load_rock_manifest(name, version)

   local function install_binary(source, target, name, version)
      if wrap_bin_scripts and fs.is_lua(source) then
         return target .. (cfg.wrapper_suffix or ""), function() return fs.wrap_script(source, target, name, version) end
      else
         return target, function() return fs.copy_binary(source, target) end
      end
   end

   local function make_mover(perms)
      return function(source, target)
         return target, function() return fs.move(source, target, perms) end
      end
   end

   local ok, err = true
   if rock_manifest.bin then
      ok, err = deploy_file_tree(rock_manifest.bin, path.bin_dir, cfg.deploy_bin_dir, install_binary, cfg.wrapper_suffix)
   end
   if ok and rock_manifest.lua then
      ok, err = deploy_file_tree(rock_manifest.lua, path.lua_dir, cfg.deploy_lua_dir, make_mover(cfg.perm_read))
   end
   if ok and rock_manifest.lib then
      ok, err = deploy_file_tree(rock_manifest.lib, path.lib_dir, cfg.deploy_lib_dir, make_mover(cfg.perm_exec))
   end

   if not ok then
      return nil, err
   end

   return manif.update_manifest(name, version, nil, deps_mode)
end

--- Delete a package from the local repository.
-- It is maintained that for each module and command the one that is provided
-- by the newest version of the lexicographically smallest package
-- is installed using unversioned name, and other versions use versioned names.
-- @param name string: name of package
-- @param version string: exact package version in string format
-- @param deps_mode: string: Which trees to check dependencies for:
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
-- @param quick boolean: do not try to fix the versioned name
-- of another version that provides the same module that
-- was deleted. This is used during 'purge', as every module
-- will be eventually deleted.
function repos.delete_version(name, version, deps_mode, quick)
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(deps_mode) == "string")

   local function delete_deployed_file_tree(file_tree, deploy_dir, suffix)
      return recurse_rock_manifest_tree(file_tree, 
         function(parent_path, parent_module, file)
            local target = dir.path(deploy_dir, parent_path, file)
            local versioned = path.versioned_name(target, deploy_dir, name, version)

            local ok, err, err_type = delete_suffixed(versioned, suffix)
            if ok then
               fs.remove_dir_tree_if_empty(dir.dir_name(versioned))
               return true
            elseif err_type == "fail" then
               return nil, err
            end

            ok, err = delete_suffixed(target, suffix)
            if not ok then
               return nil, err
            end

            if not quick then
               local next_name, next_version = manif.find_next_provider(target)
               if next_name then
                  local next_target = manif.find_conflicting_file(next_name, next_version, target)
                  local next_versioned = path.versioned_name(next_target, deploy_dir, next_name, next_version)

                  ok, err = move_suffixed(next_versioned, next_target, suffix)
                  if not ok then
                     return nil, err
                  end

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
   if not ok then return nil, err end

   fs.delete(path.install_dir(name, version))
   if not get_installed_versions(name) then
      fs.delete(dir.path(cfg.rocks_dir, name))
   end
   
   if quick then
      return true
   end

   return manif.make_manifest(cfg.rocks_dir, deps_mode)
end

return repos
