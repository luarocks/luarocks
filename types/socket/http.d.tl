local ltn12 = require("ltn12")
local type Pump = ltn12.Pump
local type Sink = ltn12.Sink
local type Source = ltn12.Source

local record http
   request: function(string): string, integer|string, string, string
   request: function(string, string): string, integer|string, string, string
   record HTTPRequest
      url: string
      sink: Sink
      method: string
      headers: {string:string}
      source: Source
      step: Pump
      proxy: string
      redirect: boolean
      create: function
   end
   request: function(HTTPRequest): string, integer|string, string, string

   PORT: integer
   PROXY: string
   TIMEOUT: integer
   USERAGENT: string
end

return http