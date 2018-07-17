
--- Functions for command-line scripts.
local cmd = {}

local unpack = unpack or table.unpack

local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")
local deps = require("luarocks.deps")
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

local function is_ownership_ok(directory)
   local me = fs.current_user()
   for _ = 1,3 do -- try up to grandparent
      local owner = fs.attributes(directory, "owner")
      if owner then
         return owner == me
      end
      directory = dir.dir_name(directory)
   end
   return false
end

do
   local function exists(file)
      local fd = io.open(file, "r")
      if fd then
         fd:close()
         return true
      end
      return false
   end
   
   local function Q(pathname)
      if pathname:match("^.:") then
         return pathname:sub(1, 2) .. '"' .. pathname:sub(3) .. '"'
      end
      return '"' .. pathname .. '"'
   end

   local function check_lua_version(lua_exe, luaver)
      if not exists(lua_exe) then
         return nil
      end
      local lv, err = util.popen_read(Q(lua_exe) .. ' -e "io.write(_VERSION:sub(5))"')
      if luaver and luaver ~= lv then
         return nil
      end
      local ljv
      if lv == "5.1" then
         ljv = util.popen_read(Q(lua_exe) .. ' -e "io.write(tostring(jit and jit.version:sub(8)))"')
         if ljv == "nil" then
            ljv = nil
         end
      end
      return lv, ljv
   end

   local find_lua_bindir
   do
      local exe_suffix = (package.config:sub(1, 1) == "\\" and ".exe" or "")

      local function insert_lua_versions(names, luaver)
         local variants = {
            "lua" .. luaver .. exe_suffix,
            "lua" .. luaver:gsub("%.", "") .. exe_suffix,
            "lua-" .. luaver .. exe_suffix,
            "lua-" .. luaver:gsub("%.", "") .. exe_suffix,
         }
         for _, name in ipairs(variants) do
            names[name] = luaver
            table.insert(names, name)
         end
      end

      find_lua_bindir = function(prefix, luaver)
         local names = {}
         if luaver then
            insert_lua_versions(names, luaver)
         else
            for v in util.lua_versions("descending") do
               insert_lua_versions(names, v)
            end
         end
         if luaver == "5.1" or not luaver then
            table.insert(names, "luajit" .. exe_suffix)
         end
         table.insert(names, "lua" .. exe_suffix)

         local bindirs = { prefix .. "/bin", prefix }
         local tried = {}
         for _, d in ipairs(bindirs) do
            for _, name in ipairs(names) do
               local lua_exe = dir.path(d, name)
               table.insert(tried, lua_exe)
               local lv, ljv = check_lua_version(lua_exe, luaver)
               if lv then
                  return name, d, lv, ljv
               end
            end
         end
         return nil, "Lua interpreter not found at " .. prefix .. "\n" ..
                     "Tried:\t" .. table.concat(tried, "\n\t")
      end
   end

   function cmd.find_lua(prefix, luaver)
      local lua_interpreter, bindir, luajitver
      lua_interpreter, bindir, luaver, luajitver = find_lua_bindir(prefix, luaver)
      if not lua_interpreter then
         return nil, bindir
      end

      return {
         lua_version = luaver,
         luajit_version = luajitver,
         lua_interpreter = lua_interpreter,
         lua_dir = prefix,
         lua_bindir = bindir,
      }
   end
end

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

local process_tree_flags
do
   local function replace_tree(flags, tree)
      tree = dir.normalize(tree)
      flags["tree"] = tree
      path.use_tree(tree)
   end

   local function find_project_dir()
      local try = "."
      for _ = 1, 10 do -- FIXME detect when root dir was hit instead
         local abs = fs.absolute_name(try)
         if fs.is_dir(abs .. "/.luarocks") and fs.is_dir(abs .. "/lua_modules") then
            abs = abs:gsub("/.$", "")
            return abs, abs .. "/lua_modules"
         elseif fs.exists(abs .. "/.luarocks-no-project") then
            return nil
         end
         try = try .. "/.."
      end
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

   process_tree_flags = function(flags)

      if cfg.local_by_default then
         flags["local"] = true
      end

      if flags["tree"] then
         local named = false
         for _, tree in ipairs(cfg.rocks_trees) do
            if type(tree) == "table" and flags["tree"] == tree.name then
               if not tree.root then
                  return nil, "Configuration error: tree '"..tree.name.."' has no 'root' field."
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
      elseif flags["project-tree"] then
         local tree = flags["project-tree"]
         table.insert(cfg.rocks_trees, 1, { name = "project", root = tree } )
         path.use_tree(tree)
      elseif flags["local"] then
         if not cfg.home_tree then
            return nil, "The --local flag is meant for operating in a user's home directory.\n"..
               "You are running as a superuser, which is intended for system-wide operation.\n"..
               "To force using the superuser's home, use --tree explicitly."
         end
         replace_tree(flags, cfg.home_tree)
      else
         local project_dir, rocks_tree = find_project_dir()
         if project_dir then
            table.insert(cfg.rocks_trees, 1, { name = "project", root = rocks_tree } )
            path.use_tree(rocks_tree)
         else
            local trees = cfg.rocks_trees
            path.use_tree(trees[#trees])
         end
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
      return debug.traceback("LuaRocks "..cfg.program_version..
         " bug (please report at https://github.com/luarocks/luarocks/issues).\n"..err, 2)
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

   if flags["deps-mode"] and not deps.check_deps_mode_flag(flags["deps-mode"]) then
      die("Invalid entry for --deps-mode.")
   end

   local lua_data
   if flags["lua-dir"] then
      local err
      lua_data, err = cmd.find_lua(flags["lua-dir"], flags["lua-version"])
      if not lua_data then
         die(err)
      end
   elseif flags["lua-version"] then
      lua_data = {
         lua_version = flags["lua-version"]
      }
   end

   local project_dir
   if flags["project-tree"] then
      project_dir = flags["project-tree"]:gsub("[/\\][^/\\]+$", "")
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
   local ok, err = cfg.init(lua_data, project_dir, util.warning)
   if not ok then
      die(err)
   end
   -----------------------------------------------------------------------------

   fs.init()

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

   ok, err = process_tree_flags(flags)
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

   if not is_ownership_ok(cfg.local_cache) then
      util.warning("The directory '" .. cfg.local_cache .. "' or its parent directory "..
                   "is not owned by the current user and the cache has been disabled. "..
                   "Please check the permissions and owner of that directory. "..
                   (cfg.is_platform("unix")
                    and ("If executing "..util.this_program("luarocks").." with sudo, you may want sudo's -H flag.")
                    or ""))
      cfg.local_cache = fs.make_temp_dir("local_cache")
      util.schedule_function(fs.delete, cfg.local_cache)
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
