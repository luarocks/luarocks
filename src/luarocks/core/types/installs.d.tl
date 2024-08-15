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

end

return installs