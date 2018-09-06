
local init = {}

local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local deps = require("luarocks.deps")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local write_rockspec = require("luarocks.cmd.write_rockspec")

init.help_summary = "Initialize a directory for a Lua project using LuaRocks."
init.help_arguments = "[<name> [<version>]]"
init.help = [[
<name> is the project name.
<version> is an optional project version.

--reset                  Regenerate .luarocks/config-5.x.lua and ./lua wrapper
                         if those already exist.

Options for specifying rockspec data:

--license="<string>"     A license string, such as "MIT/X11" or "GNU GPL v3".
--summary="<txt>"        A short one-line description summary.
--detailed="<txt>"       A longer description string.
--homepage=<url>         Project homepage.
--lua-versions=<ver>     Supported Lua versions. Accepted values are "5.1", "5.2",
                         "5.3", "5.1,5.2", "5.2,5.3", or "5.1,5.2,5.3".
--rockspec-format=<ver>  Rockspec format version, such as "1.0" or "1.1".
--lib=<lib>[,<lib>]      A comma-separated list of libraries that C files need to
                         link to.
]]

local function write_gitignore()
   local gitignore = ""
   local fd = io.open(".gitignore", "r")
   if fd then
      gitignore = fd:read("*a")
      fd:close()
      gitignore = "\n" .. gitignore .. "\n"
   end
   
   fd = io.open(".gitignore", gitignore and "a" or "w")
   for _, entry in ipairs({"/lua", "/lua_modules"}) do
      if not gitignore:find("\n"..entry.."\n", 1, true) then
         fd:write(entry.."\n")
      end
   end
   fd:close()
end

--- Driver function for "init" command.
-- @return boolean: True if succeeded, nil on errors.
function init.command(flags, name, version)

   local pwd = fs.current_dir()

   if not name then
      name = dir.base_name(pwd)
   end

   util.printout("Initializing project " .. name .. " ...")
   
   local has_rockspec = false
   for file in fs.dir() do
      if file:match("%.rockspec$") then
         has_rockspec = true
         break
      end
   end

   if not has_rockspec then
      local ok, err = write_rockspec.command(flags, name, version or "dev", pwd)
      if not ok then
         util.printerr(err)
      end
   end

   util.printout("Checking your Lua installation ...")
   local ok, err = deps.check_lua(cfg.variables)
   if not ok then
      util.warning(err)
   end
   
   util.printout("Adding entries to .gitignore ...")
   write_gitignore()

   util.printout("Preparing ./.luarocks/ ...")
   fs.make_dir(".luarocks")
   local config_file = ".luarocks/config-" .. cfg.lua_version .. ".lua"
   if not fs.exists(config_file) then
      local fd = io.open(config_file, "w")
      fd:write("-- LuaRocks configuration for use with Lua " .. cfg.lua_version .. "\n")
      if cfg.lua_interpreter then
         fd:write(("lua_interpreter = %q\n"):format(cfg.lua_interpreter))
      end
      if cfg.luajit_version then
         fd:write(("luajit_version = %q\n"):format(cfg.luajit_version))
      end
      fd:write("variables = {\n")
      local varnames = {
         "LUA_DIR",
         "LUA_INCDIR",
         "LUA_LIBDIR",
         "LUA_BINDIR",
         "LUA_INTERPRETER",
      }
      for _, varname in ipairs(varnames) do
         if cfg.variables[varname] then
            fd:write(("   %s = %q,\n"):format(varname, cfg.variables[varname]))
         end
      end
      fd:write("}\n")
      fd:close()
   else
      util.printout(config_file .. " already exists. Not overwriting it!")
   end

   util.printout("Preparing ./lua_modules/ ...")

   fs.make_dir("lua_modules/lib/luarocks/rocks-" .. cfg.lua_version)
   local tree = dir.path(pwd, "lua_modules")

   local ext = cfg.wrapper_suffix

   local luarocks_wrapper = "./luarocks" .. ext
   if not fs.exists(luarocks_wrapper) then
      util.printout("Preparing " .. luarocks_wrapper .. " ...")
      fs.wrap_script(arg[0], "luarocks", "none", nil, nil, "--project-tree", tree)
   else
      util.printout(luarocks_wrapper .. " already exists. Not overwriting it!")
   end

   local lua_wrapper = "./lua" .. ext

   if flags["reset"] then
      fs.delete(lua_wrapper)
      for v in util.lua_versions() do
         if v ~= cfg.lua_version then
            local config_file = dir.path(".luarocks", "config-"..v..".lua")
            fs.move(config_file, config_file .. "~")
         end
      end
   end

   if not fs.exists(lua_wrapper) then
      util.printout("Preparing " .. lua_wrapper .. " for version " .. cfg.lua_version .. "...")
      path.use_tree(tree)
      fs.wrap_script(nil, "lua", "all")
   else
      util.printout(lua_wrapper .. " already exists. Not overwriting it!")
   end

   return true
end

return init
