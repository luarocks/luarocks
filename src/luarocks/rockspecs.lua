local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type
local rockspecs = {}


local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local queries = require("luarocks.queries")
local type_rockspec = require("luarocks.type.rockspec")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")






local vendored_build_type_set = {
   ["builtin"] = true,
   ["cmake"] = true,
   ["command"] = true,
   ["make"] = true,
   ["module"] = true,
   ["none"] = true,
}

local rockspec_mt_funcs = {}

local rockspec_mt = {}
rockspec_mt.__index = rockspec_mt_funcs

function rockspec_mt_funcs.type()
   util.warning("The function rockspec.type() is no longer " ..
   "necessary and is now deprecated. Please update your " ..
   "plugin to remove calls to this function.")

   return "rockspec"
end














local function platform_overrides(tbl)

   if not tbl then return end

   local tblp = tbl.platforms

   if type(tblp) == "table" then
      for platform in cfg.each_platform() do
         local platform_tbl = tblp[platform]
         if type(platform_tbl) == "table" then
            util.deep_merge(tbl, platform_tbl)
         end
      end
   end
   tbl.platforms = nil
end

local function convert_dependencies(dependencies)
   local qs = {}
   for i = 1, #dependencies do
      local parsed, err = queries.from_dep_string(dependencies[i])
      if not parsed then
         return nil, "Parse error processing dependency '" .. dependencies[i] .. "': " .. tostring(err)
      end
      qs[i] = parsed
   end
   dependencies.queries = qs
   return true
end





local function configure_paths(rockspec)
   local vars = {}
   for k, v in pairs(cfg.variables) do
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

function rockspecs.from_persisted_table(filename, rockspec, globals, quick)

   if rockspec.rockspec_format then
      if vers.compare_versions(rockspec.rockspec_format, type_rockspec.rockspec_format) then
         return nil, "Rockspec format " .. rockspec.rockspec_format .. " is not supported, please upgrade LuaRocks."
      end
   end

   if not quick then
      local ok, err = type_rockspec.check(rockspec, globals or {})
      if not ok then
         return nil, err
      end
   end





   do
      local parsed_format = vers.parse_version(rockspec.rockspec_format or "1.0")
      rockspec.format_is_at_least = function(_self, version)
         return parsed_format >= vers.parse_version(version)
      end
   end

   platform_overrides(rockspec.build)
   platform_overrides(rockspec.dependencies)
   platform_overrides(rockspec.build_dependencies)
   platform_overrides(rockspec.test_dependencies)
   platform_overrides(rockspec.external_dependencies)
   platform_overrides(rockspec.source)
   platform_overrides(rockspec.hooks)
   platform_overrides(rockspec.test)

   rockspec.name = rockspec.package:lower()

   local protocol, pathname = dir.split_url(rockspec.source.url)
   if dir.is_basic_protocol(protocol) then
      rockspec.source.file = rockspec.source.file or dir.base_name(rockspec.source.url)
   end
   rockspec.source.protocol, rockspec.source.pathname = protocol, pathname


   if rockspec.source.cvs_module then rockspec.source.module = rockspec.source.cvs_module end
   if rockspec.source.cvs_tag then rockspec.source.tag = rockspec.source.cvs_tag end

   rockspec.local_abs_filename = filename
   rockspec.source.dir_set = rockspec.source.dir ~= nil
   rockspec.source.dir = rockspec.source.dir or rockspec.source.module

   rockspec.rocks_provided = util.get_rocks_provided(rockspec)

   rockspec.dependencies = rockspec.dependencies or {}
   rockspec.build_dependencies = rockspec.build_dependencies or {}
   rockspec.test_dependencies = rockspec.test_dependencies or {}
   for _, d in ipairs({ rockspec.dependencies, rockspec.build_dependencies, rockspec.test_dependencies }) do
      local _, err = convert_dependencies(d)
      if err then
         return nil, err
      end
   end

   if rockspec.build and
      rockspec.build.type and
      not vendored_build_type_set[rockspec.build.type] then
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


   return setmetatable(rockspec, rockspec_mt)
end

return rockspecs
