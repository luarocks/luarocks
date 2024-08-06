local type q = require("luarocks.core.types.query")
local type Query = q.Query

local record rockspec
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
        HG: string
        CVS: string
        LUA: string
        GPG: string
        GIT: string
        SVN: string
        CURL: string
        SSCM: string
        PREFIX: string
        LUADIR: string
        LIBDIR: string
        CONFDIR: string
        BINDIR: string
        DOCDIR: string
        CURLNOCERTFLAG: string
        LUA_INCDIR_OK: boolean
        LUA_INCDIR: string
        LUA_DIR: string
        LUA_LIBDIR_OK: boolean
        LUA_LIBDIR: string
        LUA_LIBDIR_FILE: string
        LUALIB: string
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
        identifier: string
    end
  
    record Test
        type: string
        flags: {string}
    end
  
    record Install
        lua: any
        lib: any
        conf: any
        bin: any
    end
  
    record Build
        type: string
        modules: {string: {string: string | {string}}}
        copy_directories: string
        install: Install
    end
  
    record Dependencies
        {string} 
        -- when converted:
        queries: {Query}
    end

    record Hooks
        post_install: string
        
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
        build_dependencies: Dependencies
        test_dependencies: Dependencies
        supported_platforms: {string}
        external_dependencies: {string: {string: string}}
        variables: Variables
        hooks: Hooks
        test: Test
        deploy: Deploy
        type: function(): string
        format_is_at_least: function(Rockspec, string): boolean
    end
end

return rockspec