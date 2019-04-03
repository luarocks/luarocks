--- Module implementing the LuaRocks "install" command.
-- Installs binary rocks.
local install = {}

local path = require("luarocks.path")
local repos = require("luarocks.repos")
local fetch = require("luarocks.fetch")
local util = require("luarocks.util")
local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local writer = require("luarocks.manif.writer")
local remove = require("luarocks.remove")
local search = require("luarocks.search")
local queries = require("luarocks.queries")
local cfg = require("luarocks.core.cfg")
local cmd = require("luarocks.cmd")
local dir = require("luarocks.dir")

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

--no-doc            Installs the rock without its documentation.

--verify            Verify signature of the rock being installed.
                    If rock is being downloaded, LuaRocks will attempt
                    to download the signature as well. If the rock is
                    local, the signature file should be in the same
                    directory.
                    You need the signer’s public key in your local
                    keyring for this option to work properly.

]]..util.deps_mode_help()

install.opts = util.opts_table("install.opts", {
   namespace = "string?",
   keep = "boolean",
   force = "boolean",
   force_fast = "boolean",
   no_doc = "boolean",
   deps_mode = "string",
   verify = "boolean",
})

--- Install a binary rock.
-- @param rock_file string: local or remote filename of a rock.
-- @param opts table: installation options
-- @return (string, string) or (nil, string, [string]): Name and version of
-- installed rock if succeeded or nil and an error message followed by an error code.
function install.install_binary_rock(rock_file, opts)
   assert(type(rock_file) == "string")
   assert(opts:type() == "install.opts")

   local namespace = opts.namespace
   local deps_mode = opts.deps_mode

   local name, version, arch = path.parse_name(rock_file)
   if not name then
      return nil, "Filename "..rock_file.." does not match format 'name-version-revision.arch.rock'."
   end
   
   if arch ~= "all" and arch ~= cfg.arch then
      return nil, "Incompatible architecture "..arch, "arch"
   end
   if repos.is_installed(name, version) then
      repos.delete_version(name, version, opts.deps_mode)
   end
   
   local install_dir = path.install_dir(name, version)
   
   local rollback = util.schedule_function(function()
      fs.delete(install_dir)
      fs.remove_dir_if_empty(path.versions_dir(name))
   end)

   local ok, err, errcode = fetch.fetch_and_unpack_rock(rock_file, install_dir, opts.verify)
   if not ok then return nil, err, errcode end

   local rockspec, err = fetch.load_rockspec(path.rockspec_file(name, version))
   if err then
      return nil, "Failed loading rockspec for installed package: "..err, errcode
   end

   if opts.deps_mode == "none" then
      util.warning("skipping dependency checks.")
   else
      ok, err, errcode = deps.check_external_deps(rockspec, "install")
      if err then return nil, err, errcode end
   end

   -- For compatibility with .rock files built with LuaRocks 1
   if not fs.exists(path.rock_manifest_file(name, version)) then
      ok, err = writer.make_rock_manifest(name, version)
      if err then return nil, err end
   end

   if namespace then
      ok, err = writer.make_namespace_file(name, version, namespace)
      if err then return nil, err end
   end

   if deps_mode ~= "none" then
      ok, err, errcode = deps.fulfill_dependencies(rockspec, "dependencies", deps_mode, opts.verify)
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
-- @param opts table: installation options
-- @return (string, string) or (nil, string, [string]): Name and version of
-- the rock whose dependencies were installed if succeeded or nil and an error message 
-- followed by an error code.
function install.install_binary_rock_deps(rock_file, opts)
   assert(type(rock_file) == "string")
   assert(opts:type() == "install.opts")

   local name, version, arch = path.parse_name(rock_file)
   if not name then
      return nil, "Filename "..rock_file.." does not match format 'name-version-revision.arch.rock'."
   end
   
   if arch ~= "all" and arch ~= cfg.arch then
      return nil, "Incompatible architecture "..arch, "arch"
   end

   local install_dir = path.install_dir(name, version)

   local ok, err, errcode = fetch.fetch_and_unpack_rock(rock_file, install_dir, opts.verify)
   if not ok then return nil, err, errcode end
   
   local rockspec, err = fetch.load_rockspec(path.rockspec_file(name, version))
   if err then
      return nil, "Failed loading rockspec for installed package: "..err, errcode
   end

   ok, err, errcode = deps.fulfill_dependencies(rockspec, "dependencies", opts.deps_mode, opts.verify)
   if err then return nil, err, errcode end

   util.printout()
   util.printout("Successfully installed dependencies for " ..name.." "..version)

   return name, version
end

local function install_rock_file_deps(filename, opts)
   assert(opts:type() == "install.opts")

   local name, version = install.install_binary_rock_deps(filename, opts)
   if not name then return nil, version end

   writer.check_dependencies(nil, opts.deps_mode)
   return name, version
end

local function install_rock_file(filename, opts)
   assert(type(filename) == "string")
   assert(opts:type() == "install.opts")

   local name, version = install.install_binary_rock(filename, opts)
   if not name then return nil, version end

   if opts.no_doc then
      local install_dir = path.install_dir(name, version)
      for _, f in ipairs(fs.list_dir(install_dir)) do
         local doc_dirs = { "doc", "docs" }
         for _, d in ipairs(doc_dirs) do
            if f == d then
               fs.delete(dir.path(install_dir, f))
            end
         end
      end
   end

   if (not opts.keep) and not cfg.keep_other_versions then
      local ok, err = remove.remove_other_versions(name, version, opts.force, opts.force_fast)
      if not ok then util.printerr(err) end
   end

   writer.check_dependencies(nil, opts.deps_mode)
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

   name = util.adjust_name_and_namespace(name, flags)

   local ok, err = fs.check_command_permissions(flags)
   if not ok then return nil, err, cmd.errorcodes.PERMISSIONDENIED end

   if name:match("%.rockspec$") or name:match("%.src%.rock$") then
      local build = require("luarocks.cmd.build")
      return build.command(flags, name)
   elseif name:match("%.rock$") then
      local deps_mode = deps.get_deps_mode(flags)
      local opts = install.opts({
         namespace = flags["namespace"],
         keep = not not flags["keep"],
         force = not not flags["force"],
         force_fast = not not flags["force-fast"],
         no_doc = not not flags["no-doc"],
         deps_mode = deps_mode,
         verify = not not flags["verify"],
      })
      if flags["only-deps"] then
         return install_rock_file_deps(name, opts)
      else
         return install_rock_file(name, opts)
      end
   else
      local url, err = search.find_suitable_rock(queries.new(name:lower(), version), true)
      if not url then
         return nil, err
      end
      util.printout("Installing "..url)
      return install.command(flags, url)
   end
end

return install
