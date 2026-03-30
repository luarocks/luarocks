
local record rockspecs
end

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local queries = require("luarocks.queries")
local type_rockspec = require("luarocks.type.rockspec")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")

local type Rockspec = require("luarocks.core.types.rockspec").Rockspec
local type Dependencies = require("luarocks.core.types.rockspec").Dependencies

local type Query = require("luarocks.core.types.query").Query

local vendored_build_type_set: {string: boolean} = {
   ["builtin"] = true,
   ["cmake"] = true,
   ["command"] = true,
   ["make"] = true,
   ["module"] = true, -- compatibility alias
   ["none"] = true,
}

local rockspec_mt_funcs = {}

local rockspec_mt: metatable<Rockspec> = {}
rockspec_mt.__index = rockspec_mt_funcs

function rockspec_mt_funcs.type(): string
   util.warning("The function rockspec.type() is no longer " ..
      "necessary and is now deprecated. Please update your " ..
      "plugin to remove calls to this function.")

   return "rockspec"
end

--- Perform platform-specific overrides on a table.
-- Overrides values of table with the contents of the appropriate
-- subset of its "platforms" field. The "platforms" field should
-- be a table containing subtables keyed with strings representing
-- platform names. Names that match the contents of the global
-- detected platforms setting are used. For example, if
-- platform "unix" is detected, then the fields of
-- tbl.platforms.unix will overwrite those of tbl with the same
-- names. For table values, the operation is performed recursively
-- (tbl.platforms.foo.x.y.z overrides tbl.x.y.z; other contents of
-- tbl.x are preserved).
-- @param tbl table or nil: Table which may contain a "platforms" field;
-- if it doesn't (or if nil is passed), this function does nothing.
local function platform_overrides(tbl?: {any: any})

   if not tbl then return end

   local tblp = tbl.platforms

   if tblp is {any: any} then
      for platform in cfg.each_platform() do
         local platform_tbl = tblp[platform]
         if platform_tbl is {any: any} then
            util.deep_merge(tbl, platform_tbl)
         end
      end
   end
   tbl.platforms = nil
end

local function convert_dependencies(dependencies: Dependencies): boolean, string
   local qs: {Query} = {}
   for i = 1, #dependencies do
      local parsed, err = queries.from_dep_string(dependencies[i])
      if not parsed then
         return nil, "Parse error processing dependency '"..dependencies[i].."': "..tostring(err)
      end
      qs[i] = parsed
   end
   dependencies.queries = qs
   return true
end

--- Set up path-related variables for a given rock.
-- Create a "variables" table in the rockspec table, containing
-- adjusted variables according to the configuration file.
-- @param rockspec table: The rockspec table.
local function configure_paths(rockspec: Rockspec)
   local vars: {string: string} = {}
   for k,v in pairs(cfg.variables) do
      vars[k] = v
   end
   local name, version = rockspec.name, rockspec.version
   vars.PREFIX = path.install_dir(name, version)
   vars.LUADIR = path.lua_dir(name, version)
   vars.LIBDIR = path.lib_dir(name, version)
   vars.CONFDIR = path.conf_dir(name, version)
   vars.BINDIR = path.bin_dir(name, version)
   vars.DOCDIR = path.doc_dir(name, version)
   if rockspec:format_is_at_least("3.1") then
      vars.LUA_VERSION = cfg.lua_version
   end
   rockspec.variables = vars
end

function rockspecs.from_persisted_table(filename: string, rockspec: Rockspec, globals?: {string: any}, quick?: boolean): Rockspec, string

   if rockspec.rockspec_format then
      if vers.compare_versions(rockspec.rockspec_format, type_rockspec.rockspec_format) then
         return nil, "Rockspec format "..rockspec.rockspec_format.." is not supported, please upgrade LuaRocks."
      end
   end

   if not quick then
      local ok, err = type_rockspec.check(rockspec, globals or {})
      if not ok then
         return nil, err
      end
   end

   --- Check if rockspec format version satisfies version requirement.
   -- @param rockspec table: The rockspec table.
   -- @param version string: required version.
   -- @return boolean: true if rockspec format matches version or is newer, false otherwise.
   do
      local parsed_format = vers.parse_version(rockspec.rockspec_format or "1.0")
      rockspec.format_is_at_least = function(_self: Rockspec, version: string): boolean
         return parsed_format >= vers.parse_version(version)
      end
   end

   platform_overrides(rockspec.build as {any : any})
   platform_overrides(rockspec.dependencies as {any : any})
   platform_overrides(rockspec.build_dependencies as {any : any})
   platform_overrides(rockspec.test_dependencies as {any : any})
   platform_overrides(rockspec.external_dependencies as {any : any})
   platform_overrides(rockspec.source as {any : any})
   platform_overrides(rockspec.hooks as {any : any})
   platform_overrides(rockspec.test as {any : any})

   rockspec.name = rockspec.package:lower()

   local protocol, pathname = dir.split_url(rockspec.source.url)
   if dir.is_basic_protocol(protocol) then
      rockspec.source.file = rockspec.source.file or dir.base_name(rockspec.source.url)
   end
   rockspec.source.protocol, rockspec.source.pathname = protocol, pathname

   -- Temporary compatibility
   if rockspec.source.cvs_module then rockspec.source.module = rockspec.source.cvs_module end
   if rockspec.source.cvs_tag then rockspec.source.tag = rockspec.source.cvs_tag end

   rockspec.local_abs_filename = filename
   rockspec.source.dir_set = rockspec.source.dir ~= nil
   rockspec.source.dir = rockspec.source.dir or rockspec.source.module

   rockspec.rocks_provided = util.get_rocks_provided(rockspec)

   rockspec.dependencies = rockspec.dependencies or {}
   rockspec.build_dependencies = rockspec.build_dependencies or {}
   rockspec.test_dependencies = rockspec.test_dependencies or {}
   for _, d in ipairs({rockspec.dependencies, rockspec.build_dependencies, rockspec.test_dependencies}) do
      local _, err = convert_dependencies(d)
      if err then
         return nil, err
      end
   end

   if rockspec.build
      and rockspec.build.type
      and not vendored_build_type_set[rockspec.build.type] then
      local build_pkg_name = "luarocks-build-" .. rockspec.build.type
      if not rockspec.build_dependencies then
         rockspec.build_dependencies = {}
      end

      local found = false
      for _, dep in ipairs(rockspec.build_dependencies.queries) do
         if dep.name == build_pkg_name then
            found = true
            break
         end
      end

      if not found then
         local query, errfromdep = queries.from_dep_string(build_pkg_name)
         if errfromdep then
            return nil, "Invalid dependency in rockspec: " .. errfromdep
         end
         table.insert(rockspec.build_dependencies.queries, query)
      end
   end

   if not quick then
      configure_paths(rockspec)
   end

   -- TODO remove this on LuaRocks 4.0
   return setmetatable(rockspec, rockspec_mt)
end

return rockspecs
