
--- Functions for command-line scripts.
local cmd = {}

local unpack = unpack or table.unpack

local loader = require("luarocks.loader")
local util = require("luarocks.util")
local path = require("luarocks.path")
local deps = require("luarocks.deps")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local fun = require("luarocks.fun")
local fs = require("luarocks.fs")

local program = util.this_program("luarocks")

cmd.errorcodes = {
   OK = 0,
   UNSPECIFIED = 1,
   PERMISSIONDENIED = 2,
   CONFIGFILE = 3,
   CRASH = 99
}

local function check_popen()
   local popen_ok, popen_result = pcall(io.popen, "")
   if popen_ok then
      if popen_result then
         popen_result:close()
      end
   else
      io.stderr:write("Your version of Lua does not support io.popen,\n")
      io.stderr:write("which is required by LuaRocks. Please check your Lua installation.\n")
      os.exit(cmd.errorcodes.UNSPECIFIED)
   end
end

local function check_if_config_is_present(detected, try)
   local versions = detected.lua_version 
                    and { detected.lua_version }
                    or  util.lua_versions("descending")
   return fun.find(versions, function(v)
      if util.exists(dir.path(try, ".luarocks", "config-"..v..".lua")) then
         detected.project_dir = try
         detected.lua_version = v
         return detected
      end
   end)
end

local process_tree_flags
do
   local function replace_tree(flags, root, tree)
      root = dir.normalize(root)
      flags["tree"] = root
      path.use_tree(tree or root)
   end

   local function strip_trailing_slashes()
      if type(cfg.root_dir) == "string" then
        cfg.root_dir = cfg.root_dir:gsub("/+$", "")
      else
        cfg.root_dir.root = cfg.root_dir.root:gsub("/+$", "")
      end
      cfg.rocks_dir = cfg.rocks_dir:gsub("/+$", "")
      cfg.deploy_bin_dir = cfg.deploy_bin_dir:gsub("/+$", "")
      cfg.deploy_lua_dir = cfg.deploy_lua_dir:gsub("/+$", "")
      cfg.deploy_lib_dir = cfg.deploy_lib_dir:gsub("/+$", "")
   end

   process_tree_flags = function(flags, project_dir)
   
      if flags["global"] then
         cfg.local_by_default = false
      end

      if flags["tree"] then
         local named = false
         for _, tree in ipairs(cfg.rocks_trees) do
            if type(tree) == "table" and flags["tree"] == tree.name then
               if not tree.root then
                  return nil, "Configuration error: tree '"..tree.name.."' has no 'root' field."
               end
               replace_tree(flags, tree.root, tree)
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
            return nil, "The --local flag is meant for operating in a user's home directory.\n"..
               "You are running as a superuser, which is intended for system-wide operation.\n"..
               "To force using the superuser's home, use --tree explicitly."
         else
            replace_tree(flags, cfg.home_tree)
         end
      elseif flags["project-tree"] then
         local tree = flags["project-tree"]
         table.insert(cfg.rocks_trees, 1, { name = "project", root = tree } )
         loader.load_rocks_trees()
         path.use_tree(tree)
      elseif cfg.local_by_default then
         if cfg.home_tree then
            replace_tree(flags, cfg.home_tree)
         end
      elseif project_dir then
         local project_tree = project_dir .. "/lua_modules"
         table.insert(cfg.rocks_trees, 1, { name = "project", root = project_tree } )
         loader.load_rocks_trees()
         path.use_tree(project_tree)
      else
         local trees = cfg.rocks_trees
         path.use_tree(trees[#trees])
      end

      strip_trailing_slashes()

      cfg.variables.ROCKS_TREE = cfg.rocks_dir
      cfg.variables.SCRIPTS_DIR = cfg.deploy_bin_dir

      return true
   end
end

local function process_server_flags(flags)
   if flags["server"] then
      local protocol, pathname = dir.split_url(flags["server"])
      table.insert(cfg.rocks_servers, 1, protocol.."://"..pathname)
   end

   if flags["dev"] then
      local append_dev = function(s) return dir.path(s, "dev") end
      local dev_servers = fun.traverse(cfg.rocks_servers, append_dev)
      cfg.rocks_servers = fun.concat(dev_servers, cfg.rocks_servers)
   end

   if flags["only-server"] then
      if flags["dev"] then
         return nil, "--only-server cannot be used with --dev"
      end
      if flags["server"] then
         return nil, "--only-server cannot be used with --server"
      end
      cfg.rocks_servers = { flags["only-server"] }
   end

   return true
end

local function get_lua_version(flags)
   if flags["lua-version"] then
      return flags["lua-version"] 
   end
   local dirs = {}
   if flags["project-tree"] then
      table.insert(dirs, dir.path(flags["project-tree"], "..", ".luarocks"))
   end
   if cfg.home_tree then
      table.insert(dirs, dir.path(cfg.home_tree, ".luarocks"))
   end
   table.insert(dirs, cfg.sysconfdir)
   for _, d in ipairs(dirs) do
      local f = dir.path(d, "default-lua-version.lua")
      local mod, err = loadfile(f, "t")
      if mod then
         local pok, ver = pcall(mod)
         if pok and type(ver) == "string" and ver:match("%d+.%d+") then
            if flags["verbose"] then
               util.printout("Defaulting to Lua " .. ver .. " based on " .. f .. " ...")
            end
            return ver
         end
      end
   end
   return nil
end

--- Main command-line processor.
-- Parses input arguments and calls the appropriate driver function
-- to execute the action requested on the command-line, forwarding
-- to it any additional arguments passed by the user.
-- @param description string: Short summary description of the program.
-- @param commands table: contains the loaded modules representing commands.
-- @param external_namespace string: where to look for external commands.
-- @param ... string: Arguments given on the command-line.
function cmd.run_command(description, commands, external_namespace, ...)

   check_popen()

   local function error_handler(err)
      local mode = "Arch.: " .. (cfg and cfg.arch or "unknown")
      if package.config:sub(1, 1) == "\\" then
         if cfg and cfg.fs_use_modules then
            mode = mode .. " (fs_use_modules = true)"
         end
      end
      return debug.traceback("LuaRocks "..cfg.program_version..
         " bug (please report at https://github.com/luarocks/luarocks/issues).\n"..
         mode.."\n"..err, 2)
   end

   --- Display an error message and exit.
   -- @param message string: The error message.
   -- @param exitcode number: the exitcode to use
   local function die(message, exitcode)
      assert(type(message) == "string", "bad error, expected string, got: " .. type(message))
      util.printerr("\nError: "..message)

      local ok, err = xpcall(util.run_scheduled_functions, error_handler)
      if not ok then
         util.printerr("\nError: "..err)
         exitcode = cmd.errorcodes.CRASH
      end

      os.exit(exitcode or cmd.errorcodes.UNSPECIFIED)
   end

   local function process_arguments(...)
      local args = {...}
      local cmdline_vars = {}
      local last = #args
      for i = 1, #args do
         if args[i] == "--" then
            last = i - 1
            break
         end
      end
      for i = last, 1, -1 do
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

      -- Compatibility for old names of some flags
      if flags["to"] then flags["tree"] = flags["to"] end
      if flags["from"] then flags["server"] = flags["from"] end
      if flags["nodeps"] then flags["deps-mode"] = "none" end
      if flags["only-from"] then flags["only-server"] = flags["only-from"] end
      if flags["only-sources-from"] then flags["only-sources"] = flags["only-sources-from"] end

      return flags, nonflags, cmdline_vars
   end

   local flags, nonflags, cmdline_vars = process_arguments(...)

   if flags["timeout"] then   -- setting it in the config file will kick-in earlier in the process
      local timeout = tonumber(flags["timeout"])
      if timeout then
         cfg.connection_timeout = timeout
      else
         die "Argument error: --timeout expects a numeric argument."
      end
   end

   local command
   if flags["help"] or #nonflags == 0 then
      command = "help"
   else
      command = table.remove(nonflags, 1)
   end
   command = command:gsub("-", "_")

   if command == "config" then
      if nonflags[1] == "lua_version" and nonflags[2] then
         flags["lua-version"] = nonflags[2]
      elseif nonflags[1] == "lua_dir" and nonflags[2] then
         flags["lua-dir"] = nonflags[2]
      end
   end

   local lua_version = get_lua_version(flags)

   if flags["deps-mode"] and not deps.check_deps_mode_flag(flags["deps-mode"]) then
      die("Invalid entry for --deps-mode.")
   end
   
   local lua_found = false

   local detected
   if flags["lua-dir"] then
      local err
      detected, err = util.find_lua(flags["lua-dir"], lua_version)
      if not detected then
         die(err)
      end
      lua_found = true
      assert(detected.lua_version)
      assert(detected.lua_dir)
   elseif lua_version then
      local path_sep = (package.config:sub(1, 1) == "\\" and ";" or ":")
      for bindir in os.getenv("PATH"):gmatch("[^"..path_sep.."]+") do
         local parentdir = bindir:gsub("[\\/][^\\/]+[\\/]?$", "")
         detected = util.find_lua(dir.path(parentdir), lua_version)
         if detected then
            break
         end
         detected = util.find_lua(bindir, lua_version)
         if detected then
            break
         end
      end
      if detected then
         lua_found = true
      else
         detected = {
            lua_version = lua_version,
         }
      end
   end

   if flags["project-tree"] then
      local project_tree = flags["project-tree"]:gsub("[/\\][^/\\]+$", "")
      detected = detected or {}
      detected.project_dir = project_tree
      local d = check_if_config_is_present(detected, project_tree)
      if d then
         detected = d
      end
   else
      detected = detected or {}
      local try = "."
      for _ = 1, 10 do -- FIXME detect when root dir was hit instead
         if util.exists(try .. "/.luarocks") and util.exists(try .. "/lua_modules") then
            local d = check_if_config_is_present(detected, try)
            if d then
               detected = d
               break
            end
         elseif util.exists(try .. "/.luarocks-no-project") then
            break
         end
         try = try .. "/.."
      end
   end

   -- FIXME A quick hack for the experimental Windows build
   if os.getenv("LUAROCKS_CROSS_COMPILING") then
      cfg.each_platform = function()
         local i = 0
         local plats = { "unix", "linux" }
         return function()
            i = i + 1
            return plats[i]
         end
      end
      fs.init()
   end

   -----------------------------------------------------------------------------
   local ok, err = cfg.init(detected, util.warning)
   if not ok then
      die(err)
   end
   -----------------------------------------------------------------------------

   fs.init()

   if not lua_found then
      if cfg.variables.LUA_DIR then
         local found = util.find_lua(cfg.variables.LUA_DIR, cfg.lua_version)
         if found then
            lua_found = true
         end
      end
   end

   if not lua_found then
      util.warning("Could not find a Lua interpreter for version " ..
                   lua_version .. " in your PATH. " ..
                   "Modules may not install with the correct configurations. " ..
                   "You may want to specify to the path prefix to your build " ..
                   "of Lua " .. lua_version .. " using --lua-dir")
   end
   cfg.lua_found = lua_found

   if detected.project_dir then
      detected.project_dir = fs.absolute_name(detected.project_dir)
   end

   if flags["version"] then
      util.printout(program.." "..cfg.program_version)
      util.printout(description)
      util.printout()
      os.exit(cmd.errorcodes.OK)
   end

   for _, module_name in ipairs(fs.modules(external_namespace)) do
      if not commands[module_name] then
         commands[module_name] = external_namespace.."."..module_name
      end
   end

   if flags["verbose"] then
      cfg.verbose = true
      fs.verbose()
   end

   if (not fs.current_dir()) or fs.current_dir() == "" then
      die("Current directory does not exist. Please run LuaRocks from an existing directory.")
   end

   ok, err = process_tree_flags(flags, detected.project_dir)
   if not ok then
      die(err)
   end

   ok, err = process_server_flags(flags)
   if not ok then
      die(err)
   end

   if flags["only-sources"] then
      cfg.only_sources_from = flags["only-sources"]
   end

   if command ~= "help" then
      for k, v in pairs(cmdline_vars) do
         cfg.variables[k] = v
      end
   end

   -- if running as superuser, use system cache dir
   if not cfg.home_tree then
      cfg.local_cache = dir.path(fs.system_cache_dir(), "luarocks")
   end

   if commands[command] then
      local cmd_mod = require(commands[command])
      local call_ok, ok, err, exitcode = xpcall(function()
         if command == "help" then
            return cmd_mod.command(description, commands, unpack(nonflags))
         else
            return cmd_mod.command(flags, unpack(nonflags))
         end
      end, error_handler)
      if not call_ok then
         die(ok, cmd.errorcodes.CRASH)
      elseif not ok then
         die(err, exitcode)
      end
   else
      die("Unknown command: "..command)
   end
   util.run_scheduled_functions()
end

return cmd
