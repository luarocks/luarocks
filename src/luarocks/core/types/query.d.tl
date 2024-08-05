local type version = require("luarocks.core.types.version")
local type Constraint = version.Constraint

local record query
    record Query
        name: string
        namespace: string
        constraints: {Constraint}
        substring: boolean
        arch: {string: boolean}
        type: function(): string
     end
end

return query