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
   rocks_trees: {string| Tree}
   lua_version: string
   deps_mode: string
   deploy_bin_dir: string
   deploy_lua_dir: string
   deploy_lib_dir: string
   lib_extension: string
   record Tree
      root: string
      rocks_dir: string
      lua_dir: string
      lib_dir: string
   end
   -- util
   record cache
      luajit_version_checked: boolean
      luajit_version: string
      rocks_provided: {Rockspec} --! import? or move?
   end
   record variables
      LUA: string
   end
   rocks_provided: {Rockspec}
end

return cfg