
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
local cmd = require("luarocks.cmd")

function make.cmd_options(parser)
   parser:flag("--pack-binary-rock", "Do not install rock. Instead, produce a "..
      ".rock file with the contents of compilation in the current directory.")
   parser:flag("--keep", "Do not remove previously installed versions of the "..
      "rock after building a new one. This behavior can be made permanent by "..
      "setting keep_other_versions=true in the configuration file.")
   parser:flag("--force", "If --keep is not specified, force removal of "..
      "previously installed versions if it would break dependencies.")
   parser:flag("--force-fast", "Like --force, but performs a forced removal "..
      "without reporting dependency issues.")
   parser:flag("--verify", "Verify signature of the rockspec or src.rock being "..
      "built. If the rockspec or src.rock is being downloaded, LuaRocks will "..
      "attempt to download the signature as well. Otherwise, the signature "..
      "file should be already available locally in the same directory.\n"..
      "You need the signer’s public key in your local keyring for this "..
      "option to work properly.")
   parser:flag("--sign", "To be used with --pack-binary-rock. Also produce a "..
      "signature file for the generated .rock file.")
   util.deps_mode_option(parser)
end

function make.add_to_parser(parser)
   local cmd = parser:command("make", [[
Builds sources in the current directory, but unlike "build", it does not fetch
sources, etc., assuming everything is available in the current directory. If no
argument is given, it looks for a rockspec in the current directory and in
"rockspec/" and "rockspecs/" subdirectories, picking the rockspec with newest
version or without version name. If rockspecs for different rocks are found or
there are several rockspecs without version, you must specify which to use,
through the command-line.

This command is useful as a tool for debugging rockspecs. 
To install rocks, you'll normally want to use the "install" and "build"
commands. See the help on those for details.

NB: Use `luarocks install` with the `--only-deps` flag if you want to install
only dependencies of the rockspec (see `luarocks help install`).
]], util.see_also())
      :summary("Compile package in current directory using a rockspec.")

   cmd:argument("rockspec", "Rockspec for the rock to build.")
      :args("?")

   make.cmd_options(cmd)
end

--- Driver function for "make" command.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function make.command(args)
   local rockspec_filename = args.rockspec
   if not rockspec_filename then
      local err
      rockspec_filename, err = util.get_default_rockspec()
      if not rockspec_filename then
         return nil, err
      end
   end
   if not rockspec_filename:match("rockspec$") then
      return nil, "Invalid argument: 'make' takes a rockspec as a parameter. "..util.see_help("make")
   end
   
   local rockspec, err, errcode = fetch.load_rockspec(rockspec_filename)
   if not rockspec then
      return nil, err
   end

   local name = util.adjust_name_and_namespace(rockspec.name, args)

   local opts = build.opts({
      need_to_fetch = false,
      minimal_mode = true,
      deps_mode = deps.get_deps_mode(args),
      build_only_deps = false,
      namespace = args.namespace,
      branch = args.branch,
      verify = not not args.verify,
   })

   if args.sign and not args.pack_binary_rock then
      return nil, "In the make command, --sign is meant to be used only with --pack-binary-rock"
   end

   if args.pack_binary_rock then
      return pack.pack_binary_rock(name, rockspec.version, args.sign, function()
         return build.build_rockspec(rockspec, opts)
      end)
   else
      local ok, err = fs.check_command_permissions(args)
      if not ok then return nil, err, cmd.errorcodes.PERMISSIONDENIED end
      ok, err = build.build_rockspec(rockspec, opts)
      if not ok then return nil, err end
      local name, version = ok, err

      if (not args.keep) and not cfg.keep_other_versions then
         local ok, err = remove.remove_other_versions(name, version, args.force, args.force_fast)
         if not ok then util.printerr(err) end
      end

      writer.check_dependencies(nil, deps.get_deps_mode(args))
      return name, version
   end
end

return make
