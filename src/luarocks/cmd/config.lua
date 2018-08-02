--- Module implementing the LuaRocks "config" command.
-- Queries information about the LuaRocks configuration.
local config_cmd = {}

local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local deps = require("luarocks.deps")
local dir = require("luarocks.dir")
local fun = require("luarocks.fun")

config_cmd.help_summary = "Query information about the LuaRocks configuration."
config_cmd.help_arguments = "<flag>"
config_cmd.help = [[
--lua-incdir     Path to Lua header files.

--lua-libdir     Path to Lua library files.

--lua-ver        Lua version (in major.minor format). e.g. 5.1

--system-config  Location of the system config file.

--user-config    Location of the user config file.

--rock-trees     Rocks trees in use. First the user tree, then the system tree.
]]
config_cmd.help_see_also = [[
	https://github.com/luarocks/luarocks/wiki/Config-file-format
	for detailed information on the LuaRocks config file format.
]]

local function config_file(conf)
   print(dir.normalize(conf.file))
   if conf.ok then
      return true
   else
      return nil, "file not found"
   end
end

local function printf(fmt, ...)
   print((fmt):format(...))
end

local cfg_maps = {
   external_deps_patterns = true,
   external_deps_subdirs = true,
   rocks_provided = true,
   rocks_provided_3_0 = true,
   runtime_external_deps_patterns = true,
   runtime_external_deps_subdirs = true,
   upload = true,
   variables = true,
}

local cfg_arrays = {
   disabled_servers = true,
   external_deps_dirs = true,
   rocks_trees = true,
   rocks_servers = true,
}

local cfg_skip = {
   errorcodes = true,
   flags = true,
   platforms = true,
   root_dir = true,
   upload_servers = true,
}

local function print_config(cfg)
   for k, v in util.sortedpairs(cfg) do
      k = tostring(k)
      if type(v) == "string" or type(v) == "number" then
         printf("%s = %q", k, v)
      elseif type(v) == "boolean" then
         printf("%s = %s", k, tostring(v))
      elseif type(v) == "function" or cfg_skip[k] then
         -- skip
      elseif cfg_maps[k] then
         printf("%s = {", k)
         for kk, vv in util.sortedpairs(v) do
            local keyfmt = kk:match("^[a-zA-Z_][a-zA-Z0-9_]*$") and "%s" or "[%q]"
            if type(vv) == "table" then
               local qvs = fun.map(vv, function(e) return string.format("%q", e) end)
               printf("   "..keyfmt.." = {%s},", kk, table.concat(qvs, ", "))
            else
               printf("   "..keyfmt.." = %q,", kk, vv)
            end
         end
         printf("}")
      elseif cfg_arrays[k] then
         if #v == 0 then
            printf("%s = {}", k)
         else
            printf("%s = {", k)
            for _, vv in ipairs(v) do
               if type(vv) == "string" then
                  printf("   %q,", vv)
               elseif type(vv) == "table" then
                  printf("   {")
                  if next(vv) == 1 then
                     for _, v3 in ipairs(vv) do
                        printf("      %q,", v3)
                     end
                  else
                     for k3, v3 in util.sortedpairs(vv) do
                        local keyfmt = tostring(k3):match("^[a-zA-Z_][a-zA-Z0-9_]*$") and "%s" or "[%q]"
                        printf("      "..keyfmt.." = %q,", k3, v3)
                     end
                  end
                  printf("   },")
               end
            end
            printf("}")
         end
      end
   end
end

--- Driver function for "config" command.
-- @return boolean: True if succeeded, nil on errors.
function config_cmd.command(flags)
   deps.check_lua(cfg.variables)
   if flags["lua-incdir"] then
      print(cfg.variables.LUA_INCDIR)
      return true
   end
   if flags["lua-libdir"] then
      print(cfg.variables.LUA_LIBDIR)
      return true
   end
   if flags["lua-ver"] then
      print(cfg.lua_version)
      return true
   end
   local conf = cfg.which_config()
   if flags["system-config"] then
      return config_file(conf.system)
   end
   if flags["user-config"] then
      return config_file(conf.user)
   end
   if flags["rock-trees"] then
      local cmd = require("luarocks.cmd")
      for _, tree in ipairs(cfg.rocks_trees) do
      	if type(tree) == "string" then
      	   cmd.printout(dir.normalize(tree))
      	else
      	   local name = tree.name and "\t"..tree.name or ""
      	   cmd.printout(dir.normalize(tree.root)..name)
      	end
      end
      return true
   end
   
   print_config(cfg)
   return true
end

return config_cmd
