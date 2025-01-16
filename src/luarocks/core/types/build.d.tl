local record build

   interface Build
      interface Install
         lua: {(string|integer): string}
         lib: {(string|integer): string}
         conf: {(string|integer): string}
         bin: {(string|integer): string}
      end

      type: string
      install: Install
      copy_directories: {string}
      patches: {string : string}
      extra_files: {string : string}
      macosx_deployment_target: string
   end

   record BuiltinBuild
      is Build
      where self.type == "builtin"

      record Module
         is {string}
         sources: string | {string}
         libraries: string | {string}
         defines: {string}
         incdirs: {string}
         libdirs: {string}
      end

      modules: {string: (string | Module)}
   end
end

return build
