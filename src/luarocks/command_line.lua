
--- Functions for command-line scripts.
--module("luarocks.command_line", package.seeall)
local command_line = {}

local unpack = unpack or table.unpack

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")

local program = util.this_program("luarocks")

--- Display an error message and exit.
-- @param message string: The error message.
-- @param exitcode number: the exitcode to use
local function die(message, exitcode)
   assert(type(message) == "string")

   local ok, err = pcall(util.run_scheduled_functions)
   if not ok then
      util.printerr("\nLuaRocks "..cfg.program_version.." internal bug (please report at luarocks-developers@lists.sourceforge.net):\n"..err)
   end
   util.printerr("\nError: "..message)
   os.exit(exitcode or cfg.errorcodes.UNSPECIFIED)
end

local function replace_tree(flags, args, tree)
   tree = dir.normalize(tree)
   flags["tree"] = tree
   for i = 1, #args do
      if args[i]:match("%-%-tree=") then
         args[i] = "--tree="..tree
         break
      end
   end
   path.use_tree(tree)
end

--- Main command-line processor.
-- Parses input arguments and calls the appropriate driver function
-- to execute the action requested on the command-line, forwarding
-- to it any additional arguments passed by the user.
-- Uses the global table "commands", which contains
-- the loaded modules representing commands.
-- @param ... string: Arguments given on the command-line.
function command_line.run_command(...)
   local args = {...}
   local cmdline_vars = {}
   for i = #args, 1, -1 do
      local arg = args[i]
      if arg:match("^[^-][^=]*=") then
         local var, val = arg:match("^([A-Z_][A-Z0-9_]*)=(.*)")
         if val then
            cmdline_vars[var] = val
            table.remove(args, i)
         else
            die("Invalid assignment: "..arg)
         end
      end
   end
   local nonflags = { util.parse_flags(unpack(args)) }
   local flags = table.remove(nonflags, 1)
   
   if flags["from"] then flags["server"] = flags["from"] end
   if flags["only-from"] then flags["only-server"] = flags["only-from"] end
   if flags["only-sources-from"] then flags["only-sources"] = flags["only-sources-from"] end
   if flags["to"] then flags["tree"] = flags["to"] end
   if flags["nodeps"] then
      flags["deps-mode"] = "none"
      table.insert(args, "--deps-mode=none")
   end
   
   cfg.flags = flags

   local command
   
   if flags["verbose"] then   -- setting it in the config file will kick-in earlier in the process
      cfg.verbose = true
      local fs = require("luarocks.fs")
      fs.verbose()
   end

   if flags["timeout"] then   -- setting it in the config file will kick-in earlier in the process
      local timeout = tonumber(flags["timeout"])
      if timeout then
         cfg.connection_timeout = timeout
      else
         die "Argument error: --timeout expects a numeric argument."
      end
   end

   if flags["version"] then
      util.printout(program.." "..cfg.program_version)
      util.printout(program_description)
      util.printout()
      os.exit(cfg.errorcodes.OK)
   elseif flags["help"] or #nonflags == 0 then
      command = "help"
      args = nonflags
   else
      command = nonflags[1]
      for i, arg in ipairs(args) do
         if arg == command then
            table.remove(args, i)
            break
         end
      end
   end
   command = command:gsub("-", "_")

   if flags["extensions"] then
      cfg.use_extensions = true
      local type_check = require("luarocks.type_check")
      type_check.load_extensions()
   end
   
   if cfg.local_by_default then
      flags["local"] = true
   end

   if flags["deps-mode"] and not deps.check_deps_mode_flag(flags["deps-mode"]) then
      die("Invalid entry for --deps-mode.")
   end
   
   if flags["branch"] then
     if flags["branch"] == true or flags["branch"] == "" then
       die("Argument error: use --branch=<branch-name>")
     end
     cfg.branch = flags["branch"]
   end
   
   if flags["tree"] then
      if flags["tree"] == true or flags["tree"] == "" then
         die("Argument error: use --tree=<path>")
      end
      local named = false
      for _, tree in ipairs(cfg.rocks_trees) do
         if type(tree) == "table" and flags["tree"] == tree.name then
            if not tree.root then
               die("Configuration error: tree '"..tree.name.."' has no 'root' field.")
            end
            replace_tree(flags, args, tree.root)
            named = true
            break
         end
      end
      if not named then
         local fs = require("luarocks.fs")
         local root_dir = fs.absolute_name(flags["tree"])
         replace_tree(flags, args, root_dir)
      end
   elseif flags["local"] then
      replace_tree(flags, args, cfg.home_tree)
   else
      local trees = cfg.rocks_trees
      path.use_tree(trees[#trees])
   end

   if type(cfg.root_dir) == "string" then
     cfg.root_dir = cfg.root_dir:gsub("/+$", "")
   else
     cfg.root_dir.root = cfg.root_dir.root:gsub("/+$", "")
   end
   cfg.rocks_dir = cfg.rocks_dir:gsub("/+$", "")
   cfg.deploy_bin_dir = cfg.deploy_bin_dir:gsub("/+$", "")
   cfg.deploy_lua_dir = cfg.deploy_lua_dir:gsub("/+$", "")
   cfg.deploy_lib_dir = cfg.deploy_lib_dir:gsub("/+$", "")
   
   cfg.variables.ROCKS_TREE = cfg.rocks_dir
   cfg.variables.SCRIPTS_DIR = cfg.deploy_bin_dir

   if flags["server"] then
      if flags["server"] == true then
         die("Argument error: use --server=<url>")
      end
      local protocol, path = dir.split_url(flags["server"])
      table.insert(cfg.rocks_servers, 1, protocol.."://"..path)
   end
   
   if flags["only-server"] then
      if flags["only-server"] == true then
         die("Argument error: use --only-server=<url>")
      end
      cfg.rocks_servers = { flags["only-server"] }
   end

   if flags["only-sources"] then
      cfg.only_sources_from = flags["only-sources"]
   end
  
   if command ~= "help" then
      for k, v in pairs(cmdline_vars) do
         cfg.variables[k] = v
      end
   end
   
   if commands[command] then
      -- TODO the interface of run should be modified, to receive the
      -- flags table and the (possibly unpacked) nonflags arguments.
      -- This would remove redundant parsing of arguments.
      -- I'm not changing this now to avoid messing with the run()
      -- interface, which I know some people use (even though
      -- I never published it as a public API...)
      local cmd = require(commands[command])
      local xp, ok, err, exitcode = xpcall(function() return cmd.run(unpack(args)) end, function(err)
         die(debug.traceback("LuaRocks "..cfg.program_version
            .." bug (please report at luarocks-developers@lists.sourceforge.net).\n"
            ..err, 2))
      end)
      if xp and (not ok) then
         die(err, exitcode)
      end
   else
      die("Unknown command: "..command)
   end
   util.run_scheduled_functions()
end

return command_line
