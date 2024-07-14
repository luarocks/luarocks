local record cfg
   detect_sysconfdir: function(): string
   make_platforms: function(system: string): {any: boolean}
   make_defaults: function(lua_version: string, target_cpu: string, platforms: {any: any}, home: string): {any: any}
   use_defaults: function(cfg, defaults: {any: any})
   root_dir: string | Tree
   rocks_subdir: string
   lua_modules_path: string
   lib_modules_path: string
   rocks_trees: {string| Tree}
   lua_version: string
   deps_mode: string
   record Tree
      root: string
      rocks_dir: string
      lua_dir: string
      lib_dir: string
   end
end

return cfg