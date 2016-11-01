
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

-- Tree of files installed by a package are stored
-- in its rock manifest. Some of these files have to
-- be deployed to locations where Lua can load them as
-- modules or where they can be used as commands.
-- These files are characterised by pair
-- (deploy_type, file_path), where deploy_type is the first
-- component of the file path and file_path is the rest of the
-- path. Only files with deploy_type in {"lua", "lib", "bin"}
-- are deployed somewhere.
-- Each deployed file provides an "item". An item is
-- characterised by pair (item_type, item_name).
-- item_type is "command" for files with deploy_type
-- "bin" and "module" for deploy_type in {"lua", "lib"}.
-- item_name is same as file_path for commands
-- and is produced using path.path_to_module(file_path)
-- for modules.

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
      return nil, "Could not remove " .. file .. ": " .. err
   end

   fs.delete(suffixed_file)
   if fs.exists(suffixed_file) then
      return nil, "Failed deleting " .. suffixed_file .. ": file still exists"
   end

   return true
end

-- Files can be deployed using versioned and non-versioned names.
-- Several items with same type and name can exist if they are
-- provided by different packages or versions. In any case
-- item from the newest version of lexicographically smallest package
-- is deployed using non-versioned name and others use versioned names.

local function get_deploy_paths(name, version, deploy_type, file_path)
   local deploy_dir = cfg["deploy_" .. deploy_type .. "_dir"]
   local non_versioned = dir.path(deploy_dir, file_path)
   local versioned = path.versioned_name(non_versioned, deploy_dir, name, version)
   return non_versioned, versioned
end

local function prepare_target(name, version, deploy_type, file_path, suffix)
   local non_versioned, versioned = get_deploy_paths(name, version, deploy_type, file_path)
   local item_type, item_name = manif.get_provided_item(deploy_type, file_path)
   local cur_name, cur_version = manif.get_current_provider(item_type, item_name)

   if not cur_name then
      return non_versioned
   elseif name < cur_name or (name == cur_name and deps.compare_versions(version, cur_version)) then
      -- New version has priority. Move currently provided version back using versioned name.
      local cur_deploy_type, cur_file_path = manif.get_providing_file(cur_name, cur_version, item_type, item_name)
      local cur_non_versioned, cur_versioned = get_deploy_paths(cur_name, cur_version, cur_deploy_type, cur_file_path)

      local dir_ok, dir_err = fs.make_dir(dir.dir_name(cur_versioned))
      if not dir_ok then return nil, dir_err end

      local move_ok, move_err = move_suffixed(cur_non_versioned, cur_versioned, suffix)
      if not move_ok then return nil, move_err end

      return non_versioned
   else
      -- Current version has priority, deploy new version using versioned name.
      return versioned
   end
end

--- Deploy a package from the rocks subdirectory.
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

   local rock_manifest = manif.load_rock_manifest(name, version)

   local function deploy_file_tree(deploy_type, source_dir, move_fn, suffix)
      if not rock_manifest[deploy_type] then
         return true
      end

      return recurse_rock_manifest_tree(rock_manifest[deploy_type], function(parent_path, parent_module, file)
         local file_path = parent_path .. file
         local source = dir.path(source_dir, file_path)

         local target, prepare_err = prepare_target(name, version, deploy_type, file_path, suffix)
         if not target then return nil, prepare_err end

         local dir_ok, dir_err = fs.make_dir(dir.dir_name(target))
         if not dir_ok then return nil, dir_err end

         local suffixed_target, mover = move_fn(source, target)
         if fs.exists(suffixed_target) then
            local backup = suffixed_target
            repeat
               backup = backup.."~"
            until not fs.exists(backup) -- Slight race condition here, but shouldn't be a problem.

            util.printerr("Warning: "..suffixed_target.." is not tracked by this installation of LuaRocks. Moving it to "..backup)
            local move_ok, move_err = fs.move(suffixed_target, backup)
            if not move_ok then return nil, move_err end
         end

         local move_ok, move_err = mover()
         if not move_ok then return nil, move_err end

         fs.remove_dir_tree_if_empty(dir.dir_name(source))
         return true
      end)
   end

   local function install_binary(source, target)
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

   local ok, err = deploy_file_tree("bin", path.bin_dir(name, version), install_binary, cfg.wrapper_suffix)
   if not ok then return nil, err end

   ok, err = deploy_file_tree("lua", path.lua_dir(name, version), make_mover(cfg.perm_read))
   if not ok then return nil, err end

   ok, err = deploy_file_tree("lib", path.lib_dir(name, version), make_mover(cfg.perm_exec))
   if not ok then return nil, err end

   return manif.add_to_manifest(name, version, nil, deps_mode)
end

--- Delete a package from the local repository.
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

   local rock_manifest = manif.load_rock_manifest(name, version)
   if not rock_manifest then
      return nil, "rock_manifest file not found for "..name.." "..version.." - not a LuaRocks 2 tree?"
   end

   local function delete_deployed_file_tree(deploy_type, suffix)
      if not rock_manifest[deploy_type] then
         return true
      end

      return recurse_rock_manifest_tree(rock_manifest[deploy_type], function(parent_path, parent_module, file)
         local file_path = parent_path .. file
         local non_versioned, versioned = get_deploy_paths(name, version, deploy_type, file_path)

         -- Figure out if the file is deployed using versioned or non-versioned name.
         local target
         local item_type, item_name = manif.get_provided_item(deploy_type, file_path)
         local cur_name, cur_version = manif.get_current_provider(item_type, item_name)

         if cur_name == name and cur_version == version then
            -- This package has highest priority, should be in non-versioned location.
            target = non_versioned
         else
            target = versioned
         end

         local ok, err = delete_suffixed(target, suffix)
         if not ok then return nil, err end

         if not quick and target == non_versioned then
            -- If another package provides this file, move its version
            -- into non-versioned location instead.
            local next_name, next_version = manif.get_next_provider(item_type, item_name)

            if next_name then
               local next_deploy_type, next_file_path = manif.get_providing_file(next_name, next_version, item_type, item_name)
               local next_non_versioned, next_versioned = get_deploy_paths(next_name, next_version, next_deploy_type, next_file_path)

               local move_ok, move_err = move_suffixed(next_versioned, next_non_versioned, suffix)
               if not move_ok then return nil, move_err end

               fs.remove_dir_tree_if_empty(dir.dir_name(next_versioned))
            end
         end

         fs.remove_dir_tree_if_empty(dir.dir_name(target))
         return true
      end)
   end

   local ok, err = delete_deployed_file_tree("bin", cfg.wrapper_suffix)
   if not ok then return nil, err end

   ok, err = delete_deployed_file_tree("lua")
   if not ok then return nil, err end

   ok, err = delete_deployed_file_tree("lib")
   if not ok then return nil, err end

   fs.delete(path.install_dir(name, version))
   if not get_installed_versions(name) then
      fs.delete(dir.path(cfg.rocks_dir, name))
   end

   if quick then
      return true
   end

   return manif.remove_from_manifest(name, version, nil, deps_mode)
end

return repos
