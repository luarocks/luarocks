
--- Module implementing the LuaRocks "make" command.
-- Builds sources in the current directory, but unlike "build",
-- it does not fetch sources, etc., assuming everything is 
-- available in the current directory.
--module("luarocks.make", package.seeall)
local make = {}
package.loaded["luarocks.make"] = make

local build = require("luarocks.build")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local fetch = require("luarocks.fetch")
local pack = require("luarocks.pack")
local remove = require("luarocks.remove")
local deps = require("luarocks.deps")

make.help_summary = "Compile package in current directory using a rockspec."
make.help_arguments = "[--pack-binary-rock] [<rockspec>]"
make.help = [[
Builds sources in the current directory, but unlike "build",
it does not fetch sources, etc., assuming everything is 
available in the current directory. If no argument is given,
it looks for a rockspec in the current directory and in "rockspec/"
and "rockspecs/" subdirectories, picking the rockspec with newest version
or without version name. If rockspecs for different rocks are found
or there are several rockspecs without version, you must specify which to use,
through the command-line.

This command is useful as a tool for debugging rockspecs. 
To install rocks, you'll normally want to use the "install" and
"build" commands. See the help on those for details.

--pack-binary-rock  Do not install rock. Instead, produce a .rock file
                    with the contents of compilation in the current
                    directory.

--keep              Do not remove previously installed versions of the
                    rock after installing a new one. This behavior can
                    be made permanent by setting keep_other_versions=true
                    in the configuration file.

--branch=<name>     Override the `source.branch` field in the loaded
                    rockspec. Allows to specify a different branch to 
                    fetch. Particularly for SCM rocks.

]]

--- Collect rockspecs located in a subdirectory.
-- @param versions table: A table mapping rock names to newest rockspec versions.
-- @param paths table: A table mapping rock names to newest rockspec paths.
-- @param unnamed_paths table: An array of rockspec paths that don't contain rock
-- name and version in regular format.
-- @param subdir string: path to subdirectory.
local function collect_rockspecs(versions, paths, unnamed_paths, subdir)
   if fs.is_dir(subdir) then
      for file in fs.dir(subdir) do
         file = dir.path(subdir, file)

         if file:match("rockspec$") and fs.is_file(file) then
            local rock, version = path.parse_name(file)

            if rock then
               if not versions[rock] or deps.compare_versions(version, versions[rock]) then
                  versions[rock] = version
                  paths[rock] = file
               end
            else
               table.insert(unnamed_paths, file)
            end
         end
      end
   end
end

--- Driver function for "make" command.
-- @param name string: A local rockspec.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function make.run(...)
   local flags, rockspec = util.parse_flags(...)
   assert(type(rockspec) == "string" or not rockspec)
   
   if not rockspec then
      -- Try to infer default rockspec name.
      local versions, paths, unnamed_paths = {}, {}, {}
      -- Look for rockspecs in some common locations.
      collect_rockspecs(versions, paths, unnamed_paths, ".")
      collect_rockspecs(versions, paths, unnamed_paths, "rockspec")
      collect_rockspecs(versions, paths, unnamed_paths, "rockspecs")

      if #unnamed_paths > 0 then
         -- There are rockspecs not following "name-version.rockspec" format.
         -- More than one are ambiguous.
         if #unnamed_paths > 1 then
            return nil, "Please specify which rockspec file to use."
         else
            rockspec = unnamed_paths[1]
         end
      else
         local rock = next(versions)

         if rock then
            -- If there are rockspecs for multiple rocks it's ambiguous.
            if next(versions, rock) then
               return nil, "Please specify which rockspec file to use."
            else
               rockspec = paths[rock]
            end
         else
            return nil, "Argument missing: please specify a rockspec to use on current directory."
         end
      end
   end
   if not rockspec:match("rockspec$") then
      return nil, "Invalid argument: 'make' takes a rockspec as a parameter. "..util.see_help("make")
   end

   if flags["pack-binary-rock"] then
      local rspec, err, errcode = fetch.load_rockspec(rockspec)
      if not rspec then
         return nil, err
      end
      return pack.pack_binary_rock(rspec.name, rspec.version, build.build_rockspec, rockspec, false, true, deps.get_deps_mode(flags))
   else
      local ok, err = fs.check_command_permissions(flags)
      if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end
      local _, deps_install_mode = deps.get_install_modes(flags)
      ok, err = build.build_rockspec(rockspec, false, true, deps.get_deps_mode(flags), false, deps_install_mode, {})
      if not ok then return nil, err end
      local name, version = ok, err
      if (not flags["keep"]) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, flags["force"])
         if not ok then util.printerr(err) end
      end
      return name, version
   end
end

return make
