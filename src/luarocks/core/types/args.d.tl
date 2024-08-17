local record args
    record Args
        tree: string
        global: boolean
        deps_mode: string
        ["local"]: boolean --!
        project_tree: string
        server: string
        dev: boolean
        only_server: string --!
        verbose: string
        lua_version: string
        lua_dir: string
        no_project: boolean
        input: {string}
        nodeps: boolean
        timeout: number --!
        command: string
        key: string
        value: string
        only_sources: string
        no_manifest: boolean
        force_lock: boolean
        rockspec: string
        namespace: string
        pack_binary_rock: boolean
        only_deps: boolean
        branch: string
        verify: boolean --!
        check_lua_versions: boolean --!
        pin: boolean
        no_install: boolean
        sign: boolean
        no_doc: boolean
        keep: boolean
        force: boolean
        force_fast: boolean
        rock: string
        version: string
        scope: string
        lua_incdir: string
        lua_libdir: string
        lua_ver: string
        system_config: string
        user_config: string
        rock_trees: string
        unset: boolean
        json: boolean
        home: boolean
        porcelain: boolean
        list: boolean --!
        name: string
        all: boolean
        source: string
        arch: string
        location: string
        tag: string
        output: string
        homepage: string
        rockspec_format: string
        summary: string
        detailed: string
        license: string
        lua_versions: string
        lib: string
        no_gitignore: boolean
        no_wrapper_scripts: boolean
        wrapper_dir: string
        reset: boolean
     end
end

return args