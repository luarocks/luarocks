
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
      print("\nLuaRocks "..cfg.program_version.." internal bug (please report at luarocks-developers@lists.luaforge.net):\n"..err)
   end
   print("\nError: "..message)
   os.exit(1)
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
   
   if flags["to"] then
      if flags["to"] == true then
         die("Argument error: use --to=<path>")
      end
      local root_dir = fs.absolute_name(flags["to"])
      cfg.root_dir = root_dir
      cfg.rocks_dir = path.rocks_dir(root_dir)
      cfg.scripts_dir = path.scripts_dir(root_dir)
      cfg.lua_modules_dir = path.lua_modules_dir(root_dir)
      cfg.bin_modules_dir = path.bin_modules_dir(root_dir)
   else
      local trees = cfg.rocks_trees
      for i = #trees, 1, -1 do
         local tree = trees[i]
         if fs.make_dir(tree) and fs.is_writable(tree) then
            cfg.root_dir = tree
            cfg.rocks_dir = path.rocks_dir(tree)
            cfg.scripts_dir = rawget(cfg, "scripts_dir") or path.scripts_dir(tree)
            cfg.lua_modules_dir = rawget(cfg, "lua_modules_dir") or path.lua_modules_dir(tree)
            cfg.bin_modules_dir = rawget(cfg, "bin_modules_dir") or path.bin_modules_dir(tree)
            break
         end
      end
   end

   cfg.root_dir = cfg.root_dir:gsub("/+$", "")
   cfg.rocks_dir = cfg.rocks_dir:gsub("/+$", "")
   cfg.scripts_dir = cfg.scripts_dir:gsub("/+$", "")
   cfg.lua_modules_dir = cfg.lua_modules_dir:gsub("/+$", "")
   cfg.bin_modules_dir = cfg.bin_modules_dir:gsub("/+$", "")
   
   cfg.variables.ROCKS_TREE = cfg.root_dir
   cfg.variables.SCRIPTS_DIR = cfg.scripts_dir

   if flags["from"] then
      if flags["from"] == true then
         die("Argument error: use --from=<url>")
      end
      local protocol, path = dir.split_url(flags["from"])
      table.insert(cfg.rocks_servers, 1, protocol.."://"..path)
   end
   
   if flags["only-from"] then
      if flags["only-from"] == true then
         die("Argument error: use --only-from=<url>")
      end
      cfg.rocks_servers = { flags["only-from"] }
   end
   
   local command
   
   if flags["version"] then
      print(program_name.." "..cfg.program_version)
      print(program_description)
      print()
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
   
   if command ~= "help" then
      for k, v in pairs(cmdline_vars) do
         cfg.variables[k] = v
      end
   end
   
   command = command:gsub("-", "_")
   if commands[command] then
      local xp, ok, err = xpcall(function() return commands[command].run(unpack(args)) end, function(err)
         die(debug.traceback("LuaRocks "..cfg.program_version
            .." bug (please report at luarocks-developers@lists.luaforge.net).\n"
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
