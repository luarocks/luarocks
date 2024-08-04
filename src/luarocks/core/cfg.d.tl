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
   record Tree
      root: string
      rocks_dir: string
      lua_dir: string
      lib_dir: string
   end
   -- util
   record Description
      summary: string
      detailed: string
      homepage: string
      issues_url: string
      maintainer: string
      license: string
      labels: any --!
   end

   record Variables
      CVS: string
      LUA: string
      GPG: string
      CURL: string
      PREFIX: string
      LUADIR: string
      LIBDIR: string
      CONFDIR: string
      BINDIR: string
      DOCDIR: string
      CURLNOCERTFLAG: string
   end

   record Source
      url: string
      module: string
      pathname: string
      tag: string
      md5: string
      file: string
      dir: string
      branch: string
      cvs_tag: string
      cvs_module: string
      protocol: string --! not in the rockspec definition but used
      dir_set: boolean
      platforms: any --!
   end

   record Test
      type: string
      platforms: any --! {{string: any}}?
   end

   record Install
      lua: any
      lib: any
      conf: any
      bin: any
   end

   record Build
      type: string
      modules: string
      copy_directories: string
      platforms: any --!
      install: Install
   end

   record Dependencie --!1 --? Query??
      
   end

   record Dependencies
      {Dependencie} --!1
      platforms: any --!
   end

   record BuildDependencies
      {Dependencie} --!1
      platforms: any --!
   end

   record SupportedPlatforms
   end

   record ExternalDependencies
      {Dependencie} --!1
      platforms: any --!
   end

   record TestDependencies
      {Dependencie} --!1
      platforms: any --!
   end

   record Hooks
      post_install: string
      platforms: any --!
   end

   record Deploy
      wrap_bin_scripts: boolean
   end

   record Rockspec
      rockspec_format: string
      name: string --! not in the rockspec definition but used
      package: string
      version: string
      local_abs_filename: string
      rocks_provided: {string : string}
      source: Source
      description: Description
      build: Build
      dependencies: Dependencies
      build_dependencies: BuildDependencies
      test_dependencies: TestDependencies
      supported_platforms: SupportedPlatforms
      external_dependencies: ExternalDependencies
      variables: Variables
      hooks: Hooks
      test: Test
      deploy: Deploy
      type: function(Rockspec): string
      format_is_at_least: function(Rockspec, string): boolean
   end
   
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
   rocks_servers: {{string}}
end

return cfg