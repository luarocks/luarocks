
--- Module implementing the LuaRocks "install" command.
-- Installs binary rocks.
module("luarocks.install", package.seeall)

local path = require("luarocks.path")
local rep = require("luarocks.rep")
local fetch = require("luarocks.fetch")
local util = require("luarocks.util")
local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local manif = require("luarocks.manif")
local cfg = require("luarocks.cfg")

help_summary = "Install a rock."

help_arguments = "{<rock>|<name> [<version>]}"

help = [[
Argument may be the name of a rock to be fetched from a repository
or a filename of a locally available rock.
]]

--- Install a binary rock.
-- @param rock_file string: local or remote filename of a rock.
-- @return boolean or (nil, string, [string]): True if succeeded or 
-- nil and an error message and an optional error code.
function install_binary_rock(rock_file)
   assert(type(rock_file) == "string")

   local name, version, arch = path.parse_rock_name(rock_file)
   if not name then
      return nil, "Filename "..rock_file.." does not match format 'name-version-revision.arch.rock'."
   end
   if arch ~= "all" and arch ~= cfg.arch then
      return nil, "Incompatible architecture "..arch, "arch"
   end
   if rep.is_installed(name, version) then
      rep.delete_version(name, version)
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

   ok, err, errcode = deps.check_external_deps(rockspec, "install")
   if err then return nil, err, errcode end

   -- For compatibility with .rock files built with LuaRocks 1
   if not fs.exists(path.rock_manifest_file(name, version)) then
      ok, err = manif.make_rock_manifest(name, version)
      if err then return nil, err end
   end

   ok, err, errcode = deps.fulfill_dependencies(rockspec)
   if err then return nil, err, errcode end

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

--- Driver function for the "install" command.
-- @param name string: name of a binary rock. If an URL or pathname
-- to a binary rock is given, fetches and installs it. If a rockspec or a
-- source rock is given, forwards the request to the "build" command.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number
-- may also be given.
-- @return boolean or (nil, string): True if installation was
-- successful, nil and an error message otherwise.
function run(...)
   local flags, name, version = util.parse_flags(...)
   if type(name) ~= "string" then
      return nil, "Argument missing, see help."
   end

   if name:match("%.rockspec$") or name:match("%.src%.rock$") then
      local build = require("luarocks.build")
      return build.run(name)
   elseif name:match("%.rock$") then
      return install_binary_rock(name)
   else
      local search = require("luarocks.search")
      local results, err = search.find_suitable_rock(search.make_query(name, version))
      if err then
         return nil, err
      elseif type(results) == "string" then
         local url = results
         print("Installing "..url.."...")
         return run(url)
      else
         print()
         print("Could not determine which rock to install.")
         print()
         print("Search results:")
         print("---------------")
         search.print_results(results)
         return nil, (next(results) and "Please narrow your query." or "No results found.")
      end
   end
end
