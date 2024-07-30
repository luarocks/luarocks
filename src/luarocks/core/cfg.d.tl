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
   record Source
      url: string
   end

   record Description
      summary: string
      detailed: string
      homepage: string
      issues_url: string
      maintainer: string
      license: string
   end

   record Test
      type: string
      platforms: {{string: any}}
   end

   record Rockspec --? luarocks-dev-1.rockspec
      rockspec_format: string
      name: string --? package
      version: string
      source: {Source}
      description: Description
      test_dependencies: {string}
      test: Test
      format_is_at_least: function(Rockspec, string): boolean
   end
   
   record cache
      luajit_version_checked: boolean
      luajit_version: string
      rocks_provided: {string: string} --? right type? infered from util
   end

   record variables
      LUA: string
      GPG: string
   end
   rocks_provided: {Rockspec}
   -- persist
   home: string
end

return cfg