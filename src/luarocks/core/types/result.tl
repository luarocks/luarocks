local type Query = require("luarocks.core.types.query").Query

local record result
    record Result
        name: string
        version: string
        namespace: string
        arch: string
        repo: string
        satisfies: function(Result, Query): boolean
     end
end

return result
