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
        force_lock: string
     end
end

return args