
local static_flags = {}
package.loaded["luarocks.static_flags"] = static_flags

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local manif = require("luarocks.manif")
local path = require("luarocks.path")
local repos = require("luarocks.repos")
local search = require("luarocks.search")
local util = require("luarocks.util")

util.add_run_function(static_flags)

static_flags.help_summary = "Returns all static libraries with flags required for the compiler's Lua flag."

static_flags.help_arguments = "{<name> [<version>]}"
static_flags.help = [[
The argument may be the name of locally available module with newest version
or defined version (optional), which has already built all static libraries.

This command is useful for building an application with static libraries.

Example:
$ gcc -o myapp main.c -llua $(luarocks static-flags module_name)
]]

local function print_static_flags(collected_libs)
   for i = 1, math.floor(#collected_libs / 2) do
      collected_libs[i], collected_libs[#collected_libs - i + 1] = collected_libs[#collected_libs - i + 1], collected_libs[i]
   end
   util.printout(table.concat(collected_libs, " "))
end

local function table_contains(libs_table, name)
   for _, value in pairs(libs_table) do
      if value:match("luarocks%-"..name.."%.a") then
         return true
      end
   end
   return false
end

local function collect_libs(module_name, flags, libs_table)
   if not module_name then
      return nil, "Argument missing. "..util.see_help("static_flags")
   end
   if libs_table == nil then
      libs_table = {}
   end

   local name, version = search.pick_installed_rock(module_name:lower(), nil, flags["tree"])
   if not name then
      util.printout(name..(version and " "..version or "").." is not installed.")
      return nil, version
   end

   -- Find static libraries for current module
   local rock_manifest, err = manif.load_rock_manifest(name, version)
   if not rock_manifest then
      return nil, err
   end
   repos.recurse_rock_manifest_tree(rock_manifest.lib, function(parent_path, parent_module, file)
      local file_path = parent_path .. file
      if file:match("^luarocks-(.-)" .. util.matchquote(cfg.lib_static_extension) .. "$") then
         local static_lib_path = dir.path(cfg.deploy_lib_dir, file_path)
         table.insert(libs_table, static_lib_path)
      end
      return true
   end)

   -- Add any external dependencies
   local rockspec = fetch.load_local_rockspec(path.rockspec_file(name, version), false)
   if rockspec.external_dependencies then
      for _, desc in pairs(rockspec.external_dependencies) do
         if desc.library then
            table.insert(libs_table, "-l"..desc.library)
         end
      end
   end

   -- Add luarocks dependencies of current module
   for _, dep in ipairs(rockspec.dependencies) do
      if not dep.name:match("lua$") then
         collect_libs(dep.name, flags, libs_table)
      end
   end

   return libs_table
end

function static_flags.command(flags, module_name, version)
   assert(type(version) == "string" or not version)
   local collected_libs, err = collect_libs(module_name, flags)
   if err then
      return nil, err
   end
   assert(type(collected_libs) == "table")
   print_static_flags(collected_libs)
   return collected_libs
end

return static_flags
