
--- Functions for command-line scripts.
local command_line = {}

local unpack = unpack or table.unpack

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")
local fs = require("luarocks.fs")

local program = util.this_program("luarocks")

local function error_handler(err)
   return debug.traceback("LuaRocks "..cfg.program_version..
      " bug (please report at https://github.com/keplerproject/luarocks/issues).\n"..err, 2)
end

--- Display an error message and exit.
-- @param message string: The error message.
-- @param exitcode number: the exitcode to use
local function die(message, exitcode)
   assert(type(message) == "string")
   util.printerr("\nError: "..message)

   local ok, err = xpcall(util.run_scheduled_functions, error_handler)
   if not ok then
      util.printerr("\nError: "..err)
      exitcode = cfg.errorcodes.CRASH
   end

   os.exit(exitcode or cfg.errorcodes.UNSPECIFIED)
end

local function replace_tree(flags, tree)
   tree = dir.normalize(tree)
   flags["tree"] = tree
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
   if flags.ERROR then
      die(flags.ERROR.." See --help.")
   end
   
   if flags["from"] then flags["server"] = flags["from"] end
   if flags["only-from"] then flags["only-server"] = flags["only-from"] end
   if flags["only-sources-from"] then flags["only-sources"] = flags["only-sources-from"] end
   if flags["to"] then flags["tree"] = flags["to"] end
   if flags["nodeps"] then
      flags["deps-mode"] = "none"
   end
   
   cfg.flags = flags

   local command
   
   if flags["verbose"] then   -- setting it in the config file will kick-in earlier in the process
      cfg.verbose = true
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
   else
      command = table.remove(nonflags, 1)
   end
   command = command:gsub("-", "_")
   
   if cfg.local_by_default then
      flags["local"] = true
   end

   if flags["deps-mode"] and not deps.check_deps_mode_flag(flags["deps-mode"]) then
      die("Invalid entry for --deps-mode.")
   end
   
   if flags["branch"] then
     cfg.branch = flags["branch"]
   end
   
   if flags["tree"] then
      local named = false
      for _, tree in ipairs(cfg.rocks_trees) do
         if type(tree) == "table" and flags["tree"] == tree.name then
            if not tree.root then
               die("Configuration error: tree '"..tree.name.."' has no 'root' field.")
            end
            replace_tree(flags, tree.root)
            named = true
            break
         end
      end
      if not named then
         local root_dir = fs.absolute_name(flags["tree"])
         replace_tree(flags, root_dir)
      end
   elseif flags["local"] then
      if not cfg.home_tree then
         die("The --local flag is meant for operating in a user's home directory.\n"..
             "You are running as a superuser, which is intended for system-wide operation.\n"..
             "To force using the superuser's home, use --tree explicitly.")
      end
      replace_tree(flags, cfg.home_tree)
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
      local protocol, path = dir.split_url(flags["server"])
      table.insert(cfg.rocks_servers, 1, protocol.."://"..path)
   end
   
   if flags["only-server"] then
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

   if not fs.current_dir() or fs.current_dir() == "" then
      die("Current directory does not exist. Please run LuaRocks from an existing directory.")
   end
   
   if commands[command] then
      local cmd = require(commands[command])
      local call_ok, ok, err, exitcode = xpcall(function() return cmd.command(flags, unpack(nonflags)) end, error_handler)
      if not call_ok then
         die(ok, cfg.errorcodes.CRASH)
      elseif not ok then
         die(err, exitcode)
      end
   else
      die("Unknown command: "..command)
   end
   util.run_scheduled_functions()
end

return command_line
