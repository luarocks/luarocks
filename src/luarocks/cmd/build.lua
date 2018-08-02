
--- Module implementing the LuaRocks "build" command.
-- Builds a rock, compiling its C parts if any.
local cmd_build = {}

local pack = require("luarocks.pack")
local path = require("luarocks.path")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local remove = require("luarocks.remove")
local cfg = require("luarocks.core.cfg")
local build = require("luarocks.build")
local writer = require("luarocks.manif.writer")
local search = require("luarocks.search")
local make = require("luarocks.cmd.make")
local cmd = require("luarocks.cmd")

cmd_build.help_summary = "build/compile a rock."
cmd_build.help_arguments = "[--pack-binary-rock] [--keep] {<rockspec>|<rock>|<name> [<version>]}"
cmd_build.help = [[
Build and install a rock, compiling its C parts if any.
Argument may be a rockspec file, a source rock file
or the name of a rock to be fetched from a repository.

--pack-binary-rock  Do not install rock. Instead, produce a .rock file
                    with the contents of compilation in the current
                    directory.

--keep              Do not remove previously installed versions of the
                    rock after building a new one. This behavior can
                    be made permanent by setting keep_other_versions=true
                    in the configuration file.

--branch=<name>     Override the `source.branch` field in the loaded
                    rockspec. Allows to specify a different branch to 
                    fetch. Particularly for "dev" rocks.

--only-deps         Installs only the dependencies of the rock.

]]..cmd.deps_mode_help()

--- Build and install a rock.
-- @param rock_filename string: local or remote filename of a rock.
-- @param need_to_fetch boolean: true if sources need to be fetched,
-- false if the rockspec was obtained from inside a source rock.
-- @param deps_mode: string: Which trees to check dependencies for:
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
-- @param build_only_deps boolean: true to build the listed dependencies only.
-- @param namespace string?: an optional namespace
-- @return boolean or (nil, string, [string]): True if build was successful,
-- or false and an error message and an optional error code.
local function build_rock(rock_filename, opts)
   assert(type(rock_filename) == "string")
   assert(opts:type() == "build.opts")

   local ok, err, errcode

   local unpack_dir
   unpack_dir, err, errcode = fetch.fetch_and_unpack_rock(rock_filename)
   if not unpack_dir then
      return nil, err, errcode
   end

   local rockspec_filename = path.rockspec_name_from_rock(rock_filename)

   ok, err = fs.change_dir(unpack_dir)
   if not ok then return nil, err end

   local rockspec
   rockspec, err, errcode = fetch.load_rockspec(rockspec_filename)
   if not rockspec then
      return nil, err, errcode
   end

   if opts.deps_mode == "none" then
      cmd.warning("Skipping dependency checks")
   end
   ok, err, errcode = build.build_rockspec(rockspec, opts)
   if ok then
      cmd.announce_install(rockspec)
   end

   fs.pop_dir()
   return ok, err, errcode
end

local function do_build(ns_name, version, opts)
   assert(type(ns_name) == "string")
   assert(version == nil or type(version) == "string")
   assert(opts:type() == "build.opts")

   local url, err
   if ns_name:match("%.rockspec$") or ns_name:match("%.rock$") then
      url = ns_name
   else
      url, err = search.find_src_or_rockspec(ns_name, version)
      if not url then
         return nil, err
      end
      local _, namespace = util.split_namespace(ns_name)
      opts.namespace = namespace
   end

   if url:match("%.rockspec$") then
      local rockspec, err, errcode = fetch.load_rockspec(url)
      if not rockspec then
         return nil, err, errcode
      end
      if opts.deps_mode == "none" then
         cmd.warning("Skipping dependency checks")
      end
      local name, version = build.build_rockspec(rockspec, opts)
      if not name then
         local build_err = version
         return nil, build_err
      end
      cmd.announce_install(rockspec)
      return name, version
   end

   if url:match("%.src%.rock$") then
      opts.need_to_fetch = false
   end

   return build_rock(url, opts)
end

--- Driver function for "build" command.
-- @param name string: A local or remote rockspec or rock file.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number may
-- also be given.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function cmd_build.command(flags, name, version)
   assert(type(name) == "string" or not name)
   assert(type(version) == "string" or not version)
   
   if not name then
      return make.command(flags)
   end

   name = util.adjust_name_and_namespace(name, flags)

   local opts = build.opts({
      need_to_fetch = true,
      minimal_mode = false,
      deps_mode = deps.get_deps_mode(flags),
      build_only_deps = not not flags["only-deps"],
      namespace = flags["namespace"],
      branch = not not flags["branch"],
   })

   if flags["pack-binary-rock"] then
      return pack.pack_binary_rock(name, version, function()
         opts.build_only_deps = false
         return do_build(name, version, opts)
      end)
   end
   
   local ok, err = fs.check_command_permissions(flags)
   if not ok then
      return nil, err, cmd.errorcodes.PERMISSIONDENIED
   end

   ok, err = do_build(name, version, opts)
   if not ok then return nil, err end
   name, version = ok, err

   if opts.build_only_deps then
      cmd.printout("Stopping after installing dependencies for " ..name.." "..version)
      cmd.printout()
   else
      if (not flags["keep"]) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, flags["force"], flags["force-fast"])
         if not ok then
            cmd.printerr(err)
         end
      end
   end

   writer.check_dependencies(nil, deps.get_deps_mode(flags))
   return name, version
end

return cmd_build
