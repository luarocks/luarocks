
--- Module implementing the LuaRocks "build" command.
-- Builds a rock, compiling its C parts if any.
local cmd_build = {}

local dir = require("luarocks.dir")
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

function cmd_build.add_to_parser(parser)
   local cmd = parser:command("build", "Build and install a rock, compiling its C parts if any.\n"..
      "If no arguments are given, behaves as luarocks make.", util.see_also())
      :summary("Build/compile a rock.")

   cmd:argument("rock", "A rockspec file, a source rock file, or the name of "..
      "a rock to be fetched from a repository.")
      :args("?")
   cmd:argument("version", "Rock version.")
      :args("?")

   cmd:flag("--only-deps", "Installs only the dependencies of the rock.")
   cmd:flag("--no-doc", "Installs the rock without its documentation.")
   cmd:option("--branch", "Override the `source.branch` field in the loaded "..
      "rockspec. Allows to specify a different branch to fetch. Particularly "..
      'for "dev" rocks.')
      :argname("<name>")
   make.cmd_options(cmd)
end

--- Build and install a rock.
-- @param rock_filename string: local or remote filename of a rock.
-- @param opts table: build options
-- @return boolean or (nil, string, [string]): True if build was successful,
-- or false and an error message and an optional error code.
local function build_rock(rock_filename, opts)
   assert(type(rock_filename) == "string")
   assert(opts:type() == "build.opts")

   local ok, err, errcode

   local unpack_dir
   unpack_dir, err, errcode = fetch.fetch_and_unpack_rock(rock_filename, nil, opts.verify)
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

   ok, err, errcode = build.build_rockspec(rockspec, opts)

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
      url, err = search.find_src_or_rockspec(ns_name, version, true)
      if not url then
         return nil, err
      end
      local _, namespace = util.split_namespace(ns_name)
      opts.namespace = namespace
   end

   if url:match("%.rockspec$") then
      local rockspec, err, errcode = fetch.load_rockspec(url, nil, opts.verify)
      if not rockspec then
         return nil, err, errcode
      end
      return build.build_rockspec(rockspec, opts)
   end

   if url:match("%.src%.rock$") then
      opts.need_to_fetch = false
   end

   return build_rock(url, opts)
end

local function remove_doc_dir(name, version)
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

--- Driver function for "build" command.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- When passing a package name, a version number may also be given.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function cmd_build.command(args)
   if not args.rock then
      return make.command(args)
   end

   local name = util.adjust_name_and_namespace(args.rock, args)

   local opts = build.opts({
      need_to_fetch = true,
      minimal_mode = false,
      deps_mode = deps.get_deps_mode(args),
      build_only_deps = not not args.only_deps,
      namespace = args.namespace,
      branch = args.branch,
      verify = not not args.verify,
   })

   if args.sign and not args.pack_binary_rock then
      return nil, "In the build command, --sign is meant to be used only with --pack-binary-rock"
   end

   if args.pack_binary_rock then
      return pack.pack_binary_rock(name, args.version, args.sign, function()
         opts.build_only_deps = false
         local name, version, errcode = do_build(name, args.version, opts)
         if name and args.no_doc then
            remove_doc_dir(name, version)
         end
         return name, version, errcode
      end)
   end
   
   local ok, err = fs.check_command_permissions(args)
   if not ok then
      return nil, err, cmd.errorcodes.PERMISSIONDENIED
   end

   ok, err = do_build(name, args.version, opts)
   if not ok then return nil, err end
   local version
   name, version = ok, err

   if args.no_doc then
      remove_doc_dir(name, version)
   end

   if opts.build_only_deps then
      util.printout("Stopping after installing dependencies for " ..name.." "..version)
      util.printout()
   else
      if (not args.keep) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, args.force, args.force_fast)
         if not ok then
            util.printerr(err)
         end
      end
   end

   writer.check_dependencies(nil, deps.get_deps_mode(args))
   return name, version
end

return cmd_build
