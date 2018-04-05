
--- Module implementing the LuaRocks "build" command.
-- Builds a rock, compiling its C parts if any.
local cmd_build = {}

local pack = require("luarocks.pack")
local path = require("luarocks.path")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")
local remove = require("luarocks.remove")
local cfg = require("luarocks.core.cfg")
local build = require("luarocks.build")
local writer = require("luarocks.manif.writer")
local search = require("luarocks.search")

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

]]..util.deps_mode_help()

--- Build and install a rock.
-- @param rock_file string: local or remote filename of a rock.
-- @param need_to_fetch boolean: true if sources need to be fetched,
-- false if the rockspec was obtained from inside a source rock.
-- @param deps_mode: string: Which trees to check dependencies for:
-- "one" for the current default tree, "all" for all trees,
-- "order" for all trees with priority >= the current default, "none" for no trees.
-- @param build_only_deps boolean: true to build the listed dependencies only.
-- @param namespace string?: an optional namespace
-- @return boolean or (nil, string, [string]): True if build was successful,
-- or false and an error message and an optional error code.
local function build_rock(rock_file, need_to_fetch, deps_mode, build_only_deps, namespace)
   assert(type(rock_file) == "string")
   assert(type(need_to_fetch) == "boolean")

   local ok, err, errcode
   local unpack_dir
   unpack_dir, err, errcode = fetch.fetch_and_unpack_rock(rock_file)
   if not unpack_dir then
      return nil, err, errcode
   end
   local rockspec_file = path.rockspec_name_from_rock(rock_file)
   ok, err = fs.change_dir(unpack_dir)
   if not ok then return nil, err end
   ok, err, errcode = build.build_rockspec(rockspec_file, need_to_fetch, false, deps_mode, build_only_deps, namespace)
   fs.pop_dir()
   return ok, err, errcode
end

local function build_file(filename, namespace, deps_mode, build_only_deps)
   if filename:match("%.rockspec$") then
      return build.build_rockspec(filename, true, false, deps_mode, build_only_deps, namespace)
   elseif filename:match("%.src%.rock$") then
      return build_rock(filename, false, deps_mode, build_only_deps, namespace)
   elseif filename:match("%.all%.rock$") then
      return build_rock(filename, true, deps_mode, build_only_deps, namespace)
   elseif filename:match("%.rock$") then
      return build_rock(filename, true, deps_mode, build_only_deps, namespace)
   end
end

local function do_build(name, version, namespace, deps_mode, build_only_deps)
   if name:match("%.rockspec$") or name:match("%.rock$") then
      return build_file(name, namespace, deps_mode, build_only_deps)
   else
      return search.act_on_src_or_rockspec(build_file, name, version, deps_mode, build_only_deps)
   end
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
   if type(name) ~= "string" then
      return nil, "Argument missing. "..util.see_help("build")
   end
   assert(type(version) == "string" or not version)

   name = util.adjust_name_and_namespace(name, flags)
   local deps_mode = deps.get_deps_mode(flags)
   local namespace = flags["namespace"]
   local build_only_deps = flags["only-deps"]

   if flags["pack-binary-rock"] then
      return pack.pack_binary_rock(name, version, function() return do_build(name, version, namespace, deps_mode) end)
   else
      local ok, err = fs.check_command_permissions(flags)
      if not ok then return nil, err, cfg.errorcodes.PERMISSIONDENIED end

      ok, err = do_build(name, version, namespace, deps_mode, build_only_deps)
      if not ok then return nil, err end
      name, version = ok, err

      if (not build_only_deps) and (not flags["keep"]) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, flags["force"], flags["force-fast"])
         if not ok then util.printerr(err) end
      end

      writer.check_dependencies(nil, deps.get_deps_mode(flags))
      return name, version
   end
end

return cmd_build
