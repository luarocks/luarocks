
--- @module luarocks.which_cmd
-- Driver for the `luarocks which` command.
local record which_cmd
end

local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")

local path = require("luarocks.core.path")
local manif = require("luarocks.core.manif")

local type Version = require("luarocks.core.types.version").Version
local type TreeManifest = require("luarocks.core.types.manifest").Tree_manifest
local type Tree = require("luarocks.core.types.tree").Tree
local type FilterFn = function(string, string, string, Tree, integer): string

local record Provider
   name: string
   version: Version
   module_name: string
   tree: TreeManifest
end

local type Parser = require("luarocks.vendor.argparse").Parser

local type Args = require("luarocks.core.types.args").Args

function which_cmd.add_to_parser(parser: Parser)
   local cmd = parser:command("which", 'Given a module name like "foo.bar", '..
      "output which file would be loaded to resolve that module by "..
      'luarocks.loader, like "/usr/local/lua/'..cfg.lua_version..'/foo/bar.lua".',
      util.see_also())
      :summary("Tell which file corresponds to a given module name.")

   cmd:argument("modname", "Module name.")
end

local function sort_versions(a: Provider, b: Provider): boolean
   return a.version > b.version
end

--- Find entries which provide the wanted module in the tree,
-- and store them in the array of providers for later sorting.
--
-- @param providers    The array of providers being accumulated into
-- @param entries      The packages which provide the module
-- @param tree         TreeManifest where filenames can be found.
-- @param module       The module name being looked up
-- @param filter_name  A filtering function to adjust the filename.
--
-- @return  If the current LuaRocks loader context already resolved this
-- dependency based on other dependencies, return the name of the module
-- for immediate use.
-- @return  Version of the module for immediate use, if matched.
-- @return  File name of the module for immediate use, if matched.
local function add_providers(providers: {Provider}, entries: {string}, tree: TreeManifest, module: string, filter_name: FilterFn)
   for i, entry in ipairs(entries) do
      local name, version = entry:match("^([^/]*)/(.*)$")

      local file_name = tree.manifest.repository[name][version][1].modules[module]
      if not file_name is string then
         error("Invalid data in manifest file for module " .. tostring(module) .. " (invalid data for " .. tostring(name) .. " " .. tostring(version) .. ")")
      end

      file_name = filter_name(file_name, name, version, tree.tree, i)

      table.insert(providers, {
         name = name,
         version = vers.parse_version(version),
         module_name = file_name,
         tree = tree
      })
   end
end

--- Search for a module in the rocks trees.
--
-- @param module       module name (eg. "socket.core")
-- @param filter_name  a function that takes the module file name
-- (eg "socket/core.so"), the rock name (eg "luasocket"),
-- the version (eg "2.0.2-1"), the path of the rocks tree
-- (eg "/usr/local"), and the numeric index of the matching entry, so the
-- filter function can know if the matching module was the first entry or not.
--
-- @return name of the rock containing the module (eg. "luasocket")
-- @return version of the rock (eg. "2.0.2-1")
-- @return return value of filter_name
local function select_module(module: string, filter_name: FilterFn): string, string, string
   local tree_manifests = manif.load_rocks_tree_manifests()
   if not tree_manifests then
      return nil
   end

   local providers: {Provider} = {}
   local initmodule: string
   for _, tree in ipairs(tree_manifests) do
      local entries = tree.manifest.modules[module]
      if entries then
         add_providers(providers, entries, tree, module, filter_name)
      else
         initmodule = initmodule or module .. ".init"
         entries = tree.manifest.modules[initmodule]
         if entries then
            add_providers(providers, entries, tree, initmodule, filter_name)
         end
      end
   end

   if next(providers) then
      table.sort(providers, sort_versions)
      local first = providers[1]
      return first.name, first.version.string, first.module_name
   end
end

--- Return the pathname of the file that would be loaded for a module.
--
-- @param module  module name (eg. "socket.core")
-- @param where   places to look for the module. If `where` contains
-- "l", it will search using the LuaRocks loader; if it contains "p",
-- it will look in the filesystem using package.path and package.cpath.
-- You can use both at the same time.
--
-- @return  If found, filename of the module (eg. "/usr/local/lib/lua/5.1/socket/core.so"),
-- @return  If found via the loader, the rock name; otherwise, "path" or "cpath"
-- @return  If found via the loader, the rock version; otherwise, nil
-- @return  If found via the loader, "l"; if found via package.path or package.cpath, "p".
local function which(module: string, where?: string): string, string, string, string
   where = where or "l"
   if where:match("l") then
      local rock_name, rock_version, file_name = select_module(module, path.which_i)
            if rock_name then
         local fd = io.open(file_name)
         if fd then
            fd:close()
            return file_name, rock_name, rock_version, "l"
         end
      end
   end
   if where:match("p") then
      local modpath = module:gsub("%.", "/")
      for _, v in ipairs({package.path, package.cpath}) do
         for p in v:gmatch("([^;]+)") do
            local file_name = p:gsub("%?", modpath)  -- luacheck: ignore 421
            local fd = io.open(file_name)
            if fd then
               fd:close()
               return file_name, v, nil, "p"
            end
         end
      end
   end
end

--- Driver function for "which" command.
-- @return boolean This function terminates the interpreter.
function which_cmd.command(args: Args): boolean, string
   local pathname, rock_name, rock_version, where = which(args.modname, "lp")

   if pathname then
      util.printout(pathname)
      if where == "l" then
         util.printout("(provided by " .. tostring(rock_name) .. " " .. tostring(rock_version) .. ")")
      else
         local key = rock_name
         util.printout("(found directly via package." .. key.. " -- not installed as a rock?)")
      end
      return true
   end

   return nil, "Module '" .. args.modname .. "' not found."
end

return which_cmd

