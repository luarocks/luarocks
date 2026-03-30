local type Rockspec = require("luarocks.core.types.rockspec").Rockspec

local type Tree = require("luarocks.core.types.tree").Tree

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

   variables: {string: string}
   rocks_provided: {Rockspec}
   -- persist
   home: string
   -- queries
   arch: string
   -- api
   record conf
      file: string
      found: boolean
   end

   record config_files
      system: conf
      user: conf
      project: conf
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
   init: function(?{string : string}, ?function(string)): boolean, string, string
   init_package_paths: function()
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
   accepted_build_types: {string}
   -- builtin
   gcc_rpath: boolean
   link_lua_explicitly: boolean
   obj_extension: string
   -- cmake
   cmake_generator: string
   target_cpu: string
   -- make
   makefile: string
   make: string
   -- cmd
   local_by_default: boolean
   fs_use_modules: boolean
   is_binary: boolean
   program_version: string
   homeconfdir: string
   sysconfdir: string
   luajit_version: string
   lua_found: boolean
   project_dir: string
   verbose: boolean
   project_tree: string
   -- cmd make
   keep_other_versions: boolean
   -- cmd path
   package_paths: function(string | Tree): string, string, string
   export_path_separator: string
   -- admin cache
   upload_server: string
   upload_servers: {string: {string: string}}
   -- admin add
   upload_user: string
   upload_password: string
end

return cfg