local type v = require("luarocks.core.types.version")
local type Constraint = v.Constraint

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