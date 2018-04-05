
--- Module implementing the LuaRocks "make" command.
-- Builds sources in the current directory, but unlike "build",
-- it does not fetch sources, etc., assuming everything is 
-- available in the current directory.
local make = {}

local build = require("luarocks.build")
local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")
local fetch = require("luarocks.fetch")
local pack = require("luarocks.pack")
local remove = require("luarocks.remove")
local deps = require("luarocks.deps")
local writer = require("luarocks.manif.writer")

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

NB: Use `luarocks install` with the `--only-deps` flag if you want to install
only dependencies of the rockspec (see `luarocks help install`).

--pack-binary-rock  Do not install rock. Instead, produce a .rock file
                    with the contents of compilation in the current
                    directory.

--keep              Do not remove previously installed versions of the
                    rock after installing a new one. This behavior can
                    be made permanent by setting keep_other_versions=true
                    in the configuration file.

--branch=<name>     Override the `source.branch` field in the loaded
                    rockspec. Allows to specify a different branch to 
                    fetch. Particularly for "dev" rocks.

]]

--- Driver function for "make" command.
-- @param name string: A local rockspec.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function make.command(flags, rockspec)
   assert(type(rockspec) == "string" or not rockspec)
   
   if not rockspec then
      local err
      rockspec, err = util.get_default_rockspec()
      if not rockspec then
         return nil, err
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
      return pack.pack_binary_rock(rspec.name, rspec.version, function() return build.build_rockspec(rockspec, false, true, deps.get_deps_mode(flags)) end)
   else
      local ok, err = fs.check_command_permissions(flags)
      if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end
      ok, err = build.build_rockspec(rockspec, false, true, deps.get_deps_mode(flags))
      if not ok then return nil, err end
      local name, version = ok, err

      if (not flags["keep"]) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, flags["force"], flags["force-fast"])
         if not ok then util.printerr(err) end
      end

      writer.check_dependencies(nil, deps.get_deps_mode(flags))
      return name, version
   end
end

return make
