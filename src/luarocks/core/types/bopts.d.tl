local record bopts
    record BOpts
        build_only_deps: boolean
        deps_mode: string
        verify: boolean
        minimal_mode: boolean
        need_to_fetch: boolean
        branch: string
        no_install: boolean
        pin: boolean
        namespace: string
        check_lua_versions: boolean
        rebuild: boolean
     end
end

return bopts