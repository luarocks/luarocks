
--- Functions for command-line scripts.
module("luarocks.command_line", package.seeall)

local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local dir = require("luarocks.dir")

--- Display an error message and exit.
-- @param message string: The error message.
local function die(message)
   assert(type(message) == "string")

   local ok, err = pcall(util.run_scheduled_functions)
   if not ok then
      util.printerr("\nLuaRocks "..cfg.program_version.." internal bug (please report at luarocks-developers@lists.sourceforge.net):\n"..err)
   end
   util.printerr("\nError: "..message)
   os.exit(1)
end

local function is_writable(tree)
  if type(tree) == "string" then
    return fs.make_dir(tree) and fs.is_writable(tree)
  else
    writable = true
    for k, v in pairs(tree) do
      writable = writable and fs.make_dir(v) and fs.is_writable(v)
    end
    return writable
  end
end

--- Main command-line processor.
-- Parses input arguments and calls the appropriate driver function
-- to execute the action requested on the command-line, forwarding
-- to it any additional arguments passed by the user.
-- Uses the global table "commands", which contains
-- the loaded modules representing commands.
-- @param ... string: Arguments given on the command-line.
function run_command(...)
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
   
   cfg.flags = flags

   local command
   
   if flags["version"] then
      util.printout(program_name.." "..cfg.program_version)
      util.printout(program_description)
      util.printout()
      os.exit(0)
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
   
   if flags["tree"] then
      if flags["tree"] == true then
         die("Argument error: use --tree=<path>")
      end
      local root_dir = fs.absolute_name(flags["tree"])
      path.use_tree(root_dir)
   elseif flags["local"] then
      path.use_tree(cfg.home_tree)
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
      local xp, ok, err = xpcall(function() return commands[command].run(unpack(args)) end, function(err)
         die(debug.traceback("LuaRocks "..cfg.program_version
            .." bug (please report at luarocks-developers@lists.sourceforge.net).\n"
            ..err, 2))
      end)
      if xp and (not ok) then
         die(err)
      end
   else
      die("Unknown command: "..command)
   end
   util.run_scheduled_functions()
end
