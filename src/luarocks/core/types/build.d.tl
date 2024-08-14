local type i = require("luarocks.core.types.installs")
local type Installs = i.Installs

local record build
    record Build
        type: string
        modules: {string: {string: string | {string}}}
        copy_directories: string
        install: Installs
        extra_files: {string : string}
        patches: {string : string}
        macosx_deployment_target: string
    end
end

return build