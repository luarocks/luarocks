
--- Functions for managing the repository on disk.
module("luarocks.rep", package.seeall)

local fs = require("luarocks.fs")
local path = require("luarocks.path")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")

--- Get all installed versions of a package.
-- @param name string: a package name.
-- @return table or nil: An array of strings listing installed
-- versions of a package, or nil if none is available.
function get_versions(name)
   assert(type(name) == "string")
   
   local dirs = fs.dir(path.versions_dir(name))
   return (dirs and #dirs > 0) and dirs or nil
end

--- Check if a package exists in a local repository.
-- Version numbers are compared as exact string comparison.
-- @param name string: name of package
-- @param version string: package version in string format
-- @return boolean: true if a package is installed,
-- false otherwise.
function is_installed(name, version)
   assert(type(name) == "string")
   assert(type(version) == "string")
      
   return fs.is_dir(path.install_dir(name, version))
end
         
--- Delete a package from the local repository.
-- Version numbers are compared as exact string comparison.
-- @param name string: name of package
-- @param version string: package version in string format
function delete_version(name, version)
   assert(type(name) == "string")
   assert(type(version) == "string")

   fs.delete(path.install_dir(name, version))
   if not get_versions(name) then
      fs.delete(fs.make_path(cfg.rocks_dir, name))
   end
end

--- Delete a command-line item from the bin directory.
-- @param command string: name of script
function delete_bin(command)
   assert(type(command) == "string")

   fs.delete(fs.make_path(cfg.scripts_dir, command))
end

--- Install bin entries in the repository bin dir.
-- @param name string: name of package
-- @param version string: package version in string format
-- @param single_file string or nil: optional parameter, indicating the name
-- of a single file to install; if not given, all bin files from the package
-- are installed.
-- @return boolean or (nil, string): True if succeeded or nil and
-- and error message.
function install_bins(name, version, single_file)
   assert(type(name) == "string")
   assert(type(version) == "string")

   local bindir = path.bin_dir(name, version)
   if fs.exists(bindir) then
      local ok, err = fs.make_dir(cfg.scripts_dir)
      if not ok then
         return nil, "Could not create "..cfg.scripts_dir
      end
      local files = single_file and {single_file} or fs.dir(bindir)
      for _, file in pairs(files) do
         local fullname = fs.make_path(bindir, file)
         local match = file:match("%.lua$")
         local file
         if not match then
            file = io.open(fullname)
         end
         if match or (file and file:read():match("#!.*lua.*")) then
            ok, err = fs.wrap_script(fullname, cfg.scripts_dir)
         else
            ok, err = fs.copy_binary(fullname, cfg.scripts_dir)
         end
         if file then file:close() end
         if not ok then
            return nil, err
         end
      end
   end
   return true
end

--- Obtain a list of modules within an installed package.
-- @param package string: The package name; for example "luasocket"
-- @param version string: The exact version number including revision;
-- for example "2.0.1-1".
-- @return table: A table of modules where keys are module identifiers
-- in "foo.bar" format and values are pathnames in architecture-dependent
-- "foo/bar.so" format. If no modules are found or if package or version
-- are invalid, an empty table is returned.
function package_modules(package, version)
   assert(type(package) == "string")
   assert(type(version) == "string")

   local result = {}
   local luas = fs.find(path.lua_dir(package, version))
   local libs = fs.find(path.lib_dir(package, version))
   for _, file in ipairs(luas) do
      local name = path.path_to_module(file)
      if name then
         result[name] = file
      end
   end
   for _, file in ipairs(libs) do
      local name = path.path_to_module(file)
      if name then
         result[name] = file
      end
   end
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
function package_commands(package, version)
   assert(type(package) == "string")
   assert(type(version) == "string")

   local result = {}
   local bindir = path.bin_dir(package, version)
   local bins = fs.find(bindir)
   for _, file in ipairs(bins) do
      if file then
         result[file] = fs.make_path(bindir, file)
      end
   end
   return result
end

--- Check if a rock contains binary parts or if it is pure Lua.
-- @param name string: name of an installed rock
-- @param version string: version of an installed rock
-- @return boolean: returns true if rock contains platform-specific
-- binary code, or false if it is a pure-Lua rock.
function is_binary_rock(name, version)
   local bin_dir = path.bin_dir(name, version)
   local lib_dir = path.lib_dir(name, version)
   if fs.exists(lib_dir) then
      return true
   end
   if fs.exists(bin_dir) then
      for _, name in pairs(fs.find(bin_dir)) do
         if fs.is_actual_binary(fs.make_path(bin_dir, name)) then
            return true
         end
      end
   end
   return false
end

function run_hook(rockspec, hook_name)
   local hooks = rockspec.hooks
   if not hooks then
      return true
   end
   if not hooks.substituted_variables then
      util.variable_substitutions(hooks, rockspec.variables)
      hooks.substituted_variables = true
   end
   local hook = hooks[hook_name]
   if hook then
      print(hook)
      if not fs.execute(hook) then
         return nil, "Failed running "..hook_name.." hook."
      end
   end
   return true
end
