local type i = require("luarocks.core.types.installs")
local type Installs = i.Installs

local record build

    interface Build
        type: string
        install: Installs
        copy_directories: string
        patches: {string : string}
    end

    record BuiltinBuild
        is Build
        where self.type == "builtin"

        record Module
            sources: string | {string}
            libraries: {string}
            defines: {string}
            incdirs: {string}
            libdirs: {string}
        end

        modules: {string: (string | {string} | Module)}
    end

    record MakeBuild
        is Build where self.type == "make"

        makefile: string --!
    end
end

return build