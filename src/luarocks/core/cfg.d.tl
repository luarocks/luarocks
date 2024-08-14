local type r = require("luarocks.core.types.rockspec")
local type Rockspec = r.Rockspec
local type Variables = r.Variables

local type t = require("luarocks.core.types.tree")
local type Tree = t.Tree

local record cfg
   detect_sysconfdir: function(): string
   make_platforms: function(system: string): {any: boolean}
   make_defaults: function(lua_version: string, target_cpu: string, platforms: {any: any}, home: string): {any: any}
   use_defaults: function(cfg, defaults: {any: any})
   root_dir: string | Tree
   rocks_dir: string
   rocks_subdir: string
   lua_modules_path: string
   lib_modules_path: string
   aggressive_cache: boolean
   rocks_trees: {string| Tree}
   lua_version: string
   deps_mode: string
   deploy_bin_dir: string
   deploy_lua_dir: string
   deploy_lib_dir: string
   lib_extension: string
   local_cache: string
   only_sources_from: string

   record cache
      luajit_version_checked: boolean
      luajit_version: string
      rocks_provided: {string: string} --? right type? infered from src/luarocks/util
   end

   variables: Variables
   rocks_provided: {Rockspec}
   -- persist
   home: string
   -- queries
   arch: string
   -- api
   record config_files
      record user
         file: string
      end
   end
   -- type_check
   accept_unknown_fields: boolean
   -- api
   user_agent: string
   connection_timeout: number
   record upload
      server: string
      version: string
      tool_version: string
      api_version: string
   end
   -- loader
   init: function(): boolean, string, string
   init_package_paths: function
   -- rockspecs
   each_platform: function(?string): (function():string)
   -- fetch
   rocks_servers: {{string} | string}
   -- search
   disabled_servers: {string: boolean}
   -- deps
   is_platform: function(string): boolean
   print_platforms: function(): string
   external_deps_patterns: {string: string}
   external_deps_subdirs: {string: string}
   runtime_external_deps_patterns: {string: string}
   runtime_external_deps_subdirs: {string: string}
   external_lib_extension: string
   external_deps_dirs: {string}
   -- repos
   hooks_enabled: boolean
   wrap_bin_scripts: boolean
   wrapper_suffix: string
   -- writer
   no_manifest: boolean
   accepted_build_types: {boolean}
end

return cfg