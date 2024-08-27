
--- Module implementing the LuaRocks "build" command.
-- Builds a rock, compiling its C parts if any.
local record cmd_build
   needs_lock: function(Args): boolean
end

local pack = require("luarocks.pack")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local remove = require("luarocks.remove")
local cfg = require("luarocks.core.cfg")
local build = require("luarocks.build")
local search = require("luarocks.search")
local make = require("luarocks.cmd.make")
local repos = require("luarocks.repos")

local type Parser = require("luarocks.vendor.argparse").Parser

local type Args = require("luarocks.core.types.args").Args
local type BOpts = require("luarocks.core.types.bopts").BOpts
local type Rockspec = require("luarocks.core.types.rockspec").Rockspec

function cmd_build.add_to_parser(parser: Parser)
   local cmd = parser:command("build", "Build and install a rock, compiling its C parts if any.\n"..  -- luacheck: ignore 431
      "If the sources contain a luarocks.lock file, uses it as an authoritative source for "..
      "exact version of dependencies.\n"..
      "If no arguments are given, behaves as luarocks make.", util.see_also())
      :summary("Build/compile a rock.")

   cmd:argument("rock", "A rockspec file, a source rock file, or the name of "..
      "a rock to be fetched from a repository.")
      :args("?")
      :action(util.namespaced_name_action)
   cmd:argument("version", "Rock version.")
      :args("?")

   cmd:flag("--only-deps --deps-only", "Install only the dependencies of the rock.")
   cmd:option("--branch", "Override the `source.branch` field in the loaded "..
      "rockspec. Allows to specify a different branch to fetch. Particularly "..
      'for "dev" rocks.')
      :argname("<name>")
   cmd:flag("--pin", "Create a luarocks.lock file listing the exact "..
      "versions of each dependency found for this rock (recursively), "..
      "and store it in the rock's directory. "..
      "Ignores any existing luarocks.lock file in the rock's sources.")
   make.cmd_options(cmd as Parser)
end

--- Build and install a rock.
-- @param rock_filename string: local or remote filename of a rock.
-- @param opts table: build options
-- @return boolean or (nil, string, [string]): True if build was successful,
-- or false and an error message and an optional error code.
local function build_rock(rock_filename: string, opts: BOpts): boolean, string, string

   local cwd = fs.absolute_name(dir.path("."))

   local ok, err, errcode: boolean, string, string

   local unpack_dir: string
   unpack_dir, err, errcode = fetch.fetch_and_unpack_rock(rock_filename, nil, opts.verify)
   if not unpack_dir then
      return nil, err, errcode
   end

   local rockspec_filename = path.rockspec_name_from_rock(rock_filename)

   ok, err = fs.change_dir(unpack_dir)
   if not ok then return nil, err end

   local rockspec: Rockspec
   rockspec, err, errcode = fetch.load_rockspec(rockspec_filename)
   if not rockspec then
      return nil, err, errcode
   end

   local n, v = build.build_rockspec(rockspec, opts, cwd)

   ok, err, errcode = n ~= nil, v, nil

   fs.pop_dir()
   return ok, err, errcode
end

local function do_build(name: string, namespace: string, version: string, opts: BOpts): string, string, string
   local url, err: string, string
   if name:match("%.rockspec$") or name:match("%.rock$") then
      url = name
   else
      url, err = search.find_src_or_rockspec(name, namespace, version, opts.check_lua_versions)
      if not url then
         return nil, err
      end
   end

   name, version = path.parse_name(url)
   if name and repos.is_installed(name, version) then
      if not opts.rebuild then
         util.printout(name .. " " .. version .. " is already installed in " .. path.root_dir(cfg.root_dir))
         util.printout("Use --force to reinstall.")
         return name, version, "skip"
      end
   end

   if url:match("%.rockspec$") then
      local cwd = fs.absolute_name(dir.path("."))
      local rockspec: Rockspec
      rockspec, err = fetch.load_rockspec(url, nil, opts.verify)
      if not rockspec then
         return nil, err
      end
      return build.build_rockspec(rockspec, opts, cwd)
   end

   if url:match("%.src%.rock$") then
      opts.need_to_fetch = false
   end

   local ok, errcode: boolean, string
   ok, err, errcode = build_rock(url, opts)
   if not ok then
      return nil, err, errcode
   end
   return name, version
end

--- Driver function for "build" command.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- When passing a package name, a version number may also be given.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function cmd_build.command(args: Args): boolean, string, string
   if not args.rock then
      return make.command(args)
   end

   local opts = {
      need_to_fetch = true,
      minimal_mode = false,
      deps_mode = deps.get_deps_mode(args),
      build_only_deps = not not (args.only_deps and not args.pack_binary_rock),
      namespace = args.namespace,
      branch = args.branch,
      verify = not not args.verify,
      check_lua_versions = not not args.check_lua_versions,
      pin = not not args.pin,
      rebuild = not not (args.force or args.force_fast),
      no_install = false
   }

   if args.sign and not args.pack_binary_rock then
      return nil, "In the build command, --sign is meant to be used only with --pack-binary-rock"
   end

   if args.pack_binary_rock then
      return pack.pack_binary_rock(args.rock, args.namespace, args.version, args.sign, function(): string, string
         local name, version = do_build(args.rock, args.namespace, args.version, opts)
         if name and args.no_doc then
            util.remove_doc_dir(name, version)
         end
         return name, version
      end)
   end

   local name, version, skip = do_build(args.rock, args.namespace, args.version, opts)
   if not name then
      return nil, version
   end
   if skip == "skip" then
      return name ~= nil, version
   end

   if args.no_doc then
      util.remove_doc_dir(name, version)
   end

   if opts.build_only_deps then
      util.printout("Stopping after installing dependencies for " ..name.." "..version)
      util.printout()
   else
      if (not args.keep) and not cfg.keep_other_versions then
         local ok, err, warn = remove.remove_other_versions(name, version, args.force, args.force_fast)
         if not ok then
            return nil, err
         elseif warn then
            util.printerr(err)
         end
      end
   end

   if opts.deps_mode ~= "none" then
      deps.check_dependencies(nil, deps.get_deps_mode(args))
   end
   return name ~= nil, version
end

cmd_build.needs_lock = function(args: Args): boolean
   if args.pack_binary_rock then
      return false
   end
   return true
end

return cmd_build
