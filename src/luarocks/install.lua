--- Module implementing the LuaRocks "install" command.
-- Installs binary rocks.
local install = {}
package.loaded["luarocks.install"] = install

local path = require("luarocks.path")
local repos = require("luarocks.repos")
local fetch = require("luarocks.fetch")
local util = require("luarocks.util")
local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local manif = require("luarocks.manif")
local remove = require("luarocks.remove")
local cfg = require("luarocks.cfg")

util.add_run_function(install)
install.help_summary = "Install a rock."

install.help_arguments = "{<rock>|<name> [<version>]}"

install.help = [[
Argument may be the name of a rock to be fetched from a repository
or a filename of a locally available rock.

--keep              Do not remove previously installed versions of the
                    rock after installing a new one. This behavior can
                    be made permanent by setting keep_other_versions=true
                    in the configuration file.

--only-deps         Installs only the dependencies of the rock.
]]..util.deps_mode_help()


--- Install a binary rock.
-- @param rock_file string: local or remote filename of a rock.
-- @param deps_mode: string: Which trees to check dependencies for:
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
-- @return (string, string) or (nil, string, [string]): Name and version of
-- installed rock if succeeded or nil and an error message followed by an error code.
function install.install_binary_rock(rock_file, deps_mode)
   assert(type(rock_file) == "string")

   local name, version, arch = path.parse_name(rock_file)
   if not name then
      return nil, "Filename "..rock_file.." does not match format 'name-version-revision.arch.rock'."
   end
   
   if arch ~= "all" and arch ~= cfg.arch then
      return nil, "Incompatible architecture "..arch, "arch"
   end
   if repos.is_installed(name, version) then
      repos.delete_version(name, version, deps_mode)
   end
   
   local rollback = util.schedule_function(function()
      fs.delete(path.install_dir(name, version))
      fs.remove_dir_if_empty(path.versions_dir(name))
   end)
   
   local ok, err, errcode = fetch.fetch_and_unpack_rock(rock_file, path.install_dir(name, version))
   if not ok then return nil, err, errcode end
   
   local rockspec, err, errcode = fetch.load_rockspec(path.rockspec_file(name, version))
   if err then
      return nil, "Failed loading rockspec for installed package: "..err, errcode
   end

   if deps_mode == "none" then
      util.printerr("Warning: skipping dependency checks.")
   else
      ok, err, errcode = deps.check_external_deps(rockspec, "install")
      if err then return nil, err, errcode end
   end

   -- For compatibility with .rock files built with LuaRocks 1
   if not fs.exists(path.rock_manifest_file(name, version)) then
      ok, err = manif.make_rock_manifest(name, version)
      if err then return nil, err end
   end

   if deps_mode ~= "none" then
      ok, err, errcode = deps.fulfill_dependencies(rockspec, deps_mode)
      if err then return nil, err, errcode end
   end

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

--- Installs the dependencies of a binary rock.
-- @param rock_file string: local or remote filename of a rock.
-- @param deps_mode: string: Which trees to check dependencies for:
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
-- @return (string, string) or (nil, string, [string]): Name and version of
-- the rock whose dependencies were installed if succeeded or nil and an error message 
-- followed by an error code.
function install.install_binary_rock_deps(rock_file, deps_mode)
   assert(type(rock_file) == "string")

   local name, version, arch = path.parse_name(rock_file)
   if not name then
      return nil, "Filename "..rock_file.." does not match format 'name-version-revision.arch.rock'."
   end
   
   if arch ~= "all" and arch ~= cfg.arch then
      return nil, "Incompatible architecture "..arch, "arch"
   end

   local ok, err, errcode = fetch.fetch_and_unpack_rock(rock_file, path.install_dir(name, version))
   if not ok then return nil, err, errcode end
   
   local rockspec, err, errcode = fetch.load_rockspec(path.rockspec_file(name, version))
   if err then
      return nil, "Failed loading rockspec for installed package: "..err, errcode
   end

   ok, err, errcode = deps.fulfill_dependencies(rockspec, deps_mode)
   if err then return nil, err, errcode end

   util.printout()
   util.printout("Successfully installed dependencies for " ..name.." "..version)

   return name, version
end

--- Driver function for the "install" command.
-- @param name string: name of a binary rock. If an URL or pathname
-- to a binary rock is given, fetches and installs it. If a rockspec or a
-- source rock is given, forwards the request to the "build" command.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number
-- may also be given.
-- @return boolean or (nil, string, exitcode): True if installation was
-- successful, nil and an error message otherwise. exitcode is optionally returned.
function install.command(flags, name, version)
   if type(name) ~= "string" then
      return nil, "Argument missing. "..util.see_help("install")
   end

   local ok, err = fs.check_command_permissions(flags)
   if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end

   if name:match("%.rockspec$") or name:match("%.src%.rock$") then
      local build = require("luarocks.build")
      return build.command(flags, name)
   elseif name:match("%.rock$") then
      if flags["only-deps"] then
         ok, err = install.install_binary_rock_deps(name, deps.get_deps_mode(flags))
      else
         ok, err = install.install_binary_rock(name, deps.get_deps_mode(flags))
      end
      if not ok then return nil, err end
      name, version = ok, err

      if (not flags["only-deps"]) and (not flags["keep"]) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, flags["force"], flags["force-fast"])
         if not ok then util.printerr(err) end
      end

      manif.check_dependencies(nil, deps.get_deps_mode(flags))
      return name, version
   else
      local search = require("luarocks.search")
      local url, err = search.find_suitable_rock(search.make_query(name:lower(), version))
      if not url then
         return nil, err
      end
      util.printout("Installing "..url)
      return install.command(flags, url)
   end
end

return install
