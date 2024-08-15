local type i = require("luarocks.core.types.installs")
local type Installs = i.Installs

local record build

    interface Build
        type: string
        install: Installs
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


    record CMakeBuild
        is Build where self.type == "cmake"

        cmake: string
        variables: {string: string}
    end

    record CommandBuild
        is Build where self.type == "command"

        build_command: string
        install_command: string
    end

    record MakeBuild
        is Build where self.type == "make"

        makefile: string
        build_target: string
        build_pass: boolean
        install_target: string
        install_pass: boolean
        build_variables: {string} --!
        install_variables: {string}
        variables: {string: string}
    end
end

return build