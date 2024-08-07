local type q = require("luarocks.core.types.query")
local type Query = q.Query

local record result
    record Result
        name: string
        version: string
        namespace: string
        arch: string
        repo: string
        type: function(): string
        satisfies: function(Result, Query): boolean
     end
end

return result