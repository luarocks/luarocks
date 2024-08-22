local record installs
   record InstallDir
      name: string
      is_module_path: boolean
      perms: string
   end

   record InstallDirs
      lua: InstallDir
      lib: InstallDir
      conf: InstallDir
      bin: InstallDir
   end

   record IOpts
      namespace: string
      deps_mode: string
      force: boolean
      force_fast: boolean
      verify: boolean
      no_doc: boolean
      keep: boolean
   end

end

return installs