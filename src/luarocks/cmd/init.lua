
local init = {}

local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local util = require("luarocks.util")
local write_rockspec = require("luarocks.cmd.write_rockspec")

init.help_summary = "Initialize a directory for a Lua project using LuaRocks."
init.help_arguments = "[<name> [<version>]]"
init.help = [[
<name> is the project name.
<version> is an optional project version.

--license="<string>"     A license string, such as "MIT/X11" or "GNU GPL v3".
--summary="<txt>"        A short one-line description summary.
--detailed="<txt>"       A longer description string.
--homepage=<url>         Project homepage.
--lua-version=<ver>      Supported Lua versions. Accepted values are "5.1", "5.2",
                         "5.3", "5.1,5.2", "5.2,5.3", or "5.1,5.2,5.3".
--rockspec-format=<ver>  Rockspec format version, such as "1.0" or "1.1".
--lib=<lib>[,<lib>]      A comma-separated list of libraries that C files need to
                         link to.
]]

local function write_gitignore()
   if fs.exists(".gitignore") then
      return
   end
   local fd = io.open(".gitignore", "w")
   fd:write("lua_modules\n")
   fd:write("lua\n")
   fd:close()
end

--- Driver function for "init" command.
-- @return boolean: True if succeeded, nil on errors.
function init.command(flags, name, version)

   local pwd = fs.current_dir()

   if not name then
      name = dir.base_name(pwd)
   end

   util.printout("Initializing project " .. name)
   
   local ok, err = write_rockspec.command(flags, name, version or "dev", pwd)
   if not ok then
      util.printerr(err)
   end
   
   write_gitignore()

   fs.make_dir("lua_modules/lib/luarocks/rocks-" .. cfg.lua_version)
   local tree = dir.path(pwd, "lua_modules")

   fs.wrap_script(arg[0], "luarocks", nil, nil, "--tree", tree)

   path.use_tree(tree)
   fs.wrap_script(nil, "lua")

   return true
end

return init
