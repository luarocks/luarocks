local type Query = require("luarocks.core.types.query").Query

local type Build = require("luarocks.core.types.build").Build

local record rockspec
    record Description
        summary: string
        detailed: string
        homepage: string
        issues_url: string
        maintainer: string
        license: string
        labels: {string}
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
        script: string
        command: string
        busted_executable: string
        flags: {string}
    end

    record Dependencies
        {string}
        -- when converted:
        queries: {Query}
    end

    record Hooks
        post_install: string
        substituted_variables: boolean
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
        variables: {string: string}
        hooks: Hooks
        test: Test
        deploy: Deploy
        format_is_at_least: function(Rockspec, string): boolean
    end
end

return rockspec
