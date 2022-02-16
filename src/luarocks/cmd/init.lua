
local init = {}

local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local deps = require("luarocks.deps")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local persist = require("luarocks.persist")
local write_rockspec = require("luarocks.cmd.write_rockspec")

function init.add_to_parser(parser)
   local cmd = parser:command("init", "Initialize a directory for a Lua project using LuaRocks.", util.see_also())

   cmd:argument("name", "The project name.")
      :args("?")
   cmd:argument("version", "An optional project version.")
      :args("?")
   cmd:flag("--reset", "Delete .luarocks/config-5.x.lua and ./lua and generate new ones.")

   cmd:group("Options for specifying rockspec data", write_rockspec.cmd_options(cmd))
end

local function write_gitignore(entries)
   local gitignore = ""
   local fd = io.open(".gitignore", "r")
   if fd then
      gitignore = fd:read("*a")
      fd:close()
      gitignore = "\n" .. gitignore .. "\n"
   end

   fd = io.open(".gitignore", gitignore and "a" or "w")
   for _, entry in ipairs(entries) do
      entry = "/" .. entry
      if not gitignore:find("\n"..entry.."\n", 1, true) then
         fd:write(entry.."\n")
      end
   end
   fd:close()
end

--- Driver function for "init" command.
-- @return boolean: True if succeeded, nil on errors.
function init.command(args)

   local pwd = fs.current_dir()

   if not args.name then
      args.name = dir.base_name(pwd)
      if args.name == "/" then
         return nil, "When running from the root directory, please specify the <name> argument"
      end
   end

   util.title("Initializing project '" .. args.name .. "' for Lua " .. cfg.lua_version .. " ...")

   util.printout("Checking your Lua installation ...")
   if not cfg.lua_found then
      return nil, "Lua installation is not found."
   end
   local ok, err = deps.check_lua_incdir(cfg.variables)
   if not ok then
      return nil, err
   end

   local has_rockspec = false
   for file in fs.dir() do
      if file:match("%.rockspec$") then
         has_rockspec = true
         break
      end
   end

   if not has_rockspec then
      args.version = args.version or "dev"
      args.location = pwd
      local ok, err = write_rockspec.command(args)
      if not ok then
         util.printerr(err)
      end
   end

   local ext = cfg.wrapper_suffix
   local luarocks_wrapper = "luarocks" .. ext
   local lua_wrapper = "lua" .. ext

   util.printout("Adding entries to .gitignore ...")
   write_gitignore({ luarocks_wrapper, lua_wrapper, "lua_modules", ".luarocks" })

   util.printout("Preparing ./.luarocks/ ...")
   fs.make_dir(".luarocks")
   local config_file = ".luarocks/config-" .. cfg.lua_version .. ".lua"

   if args.reset then
      fs.delete(lua_wrapper)
      fs.delete(config_file)
   end

   local config_tbl, err = persist.load_config_file_if_basic(config_file, cfg)
   if config_tbl then
      local globals = {
         "lua_interpreter",
      }
      for _, v in ipairs(globals) do
         if cfg[v] then
            config_tbl[v] = cfg[v]
         end
      end

      local varnames = {
         "LUA_DIR",
         "LUA_INCDIR",
         "LUA_LIBDIR",
         "LUA_BINDIR",
         "LUA_INTERPRETER",
      }
      for _, varname in ipairs(varnames) do
         if cfg.variables[varname] then
            config_tbl.variables = config_tbl.variables or {}
            config_tbl.variables[varname] = cfg.variables[varname]
         end
      end
      local ok, err = persist.save_from_table(config_file, config_tbl)
      if ok then
         util.printout("Wrote " .. config_file)
      else
         util.printout("Failed writing " .. config_file .. ": " .. err)
      end
   else
      util.printout("Will not attempt to overwrite " .. config_file)
   end

   ok, err = persist.save_default_lua_version(".luarocks", cfg.lua_version)
   if not ok then
      util.printout("Failed setting default Lua version: " .. err)
   end

   util.printout("Preparing ./lua_modules/ ...")

   fs.make_dir("lua_modules/lib/luarocks/rocks-" .. cfg.lua_version)
   local tree = dir.path(pwd, "lua_modules")

   luarocks_wrapper = dir.path(".", luarocks_wrapper)
   if not fs.exists(luarocks_wrapper) then
      util.printout("Preparing " .. luarocks_wrapper .. " ...")
      fs.wrap_script(arg[0], luarocks_wrapper, "none", nil, nil, "--project-tree", tree)
   else
      util.printout(luarocks_wrapper .. " already exists. Not overwriting it!")
   end

   lua_wrapper = dir.path(".", lua_wrapper)
   local write_lua_wrapper = true
   if fs.exists(lua_wrapper) then
      if not util.lua_is_wrapper(lua_wrapper) then
         util.printout(lua_wrapper .. " already exists and does not look like a wrapper script. Not overwriting.")
         write_lua_wrapper = false
      end
   end

   if write_lua_wrapper then
      local interp = dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)
      if util.check_lua_version(interp, cfg.lua_version) then
         util.printout("Preparing " .. lua_wrapper .. " for version " .. cfg.lua_version .. "...")
         path.use_tree(tree)
         fs.wrap_script(nil, lua_wrapper, "all")
      else
         util.warning("No Lua interpreter detected for version " .. cfg.lua_version .. ". Not creating " .. lua_wrapper)
      end
   end

   return true
end

return init
