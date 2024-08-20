local type Constraint = require("luarocks.core.types.version").Constraint

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