local record installs
    record Install
        is {string}
        name: string
        is_module_path: boolean
        perms: string
    end
  
    record Installs
        lua: Install
        lib: Install
        conf: Install
        bin: Install
    end
end

return installs