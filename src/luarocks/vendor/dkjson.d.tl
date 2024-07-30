
--[[
- local type json = {string:json}
]]

local record dkjson
   record JsonState
      indent: boolean
      keyorder: {string}
      level: number
      buffer: {string}
      bufferlen: number
      tables: {table:boolean}
      exception: function(string, string, string, string): boolean|string, string
   end
   encode: function({string:any}, JsonState): string

   decode: function(string, number, any, table): {string:any}

   null: table

   version: string

   quotestring: function(string): string

   addnewline: function(JsonState)

   encodeexception: function(string, any, JsonState, string): string

   use_lpeg: function(): dkjson
end

return dkjson
