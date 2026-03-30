local ssl = require("ssl")
local SSLCertificate = ssl.SSLCertificate
local SSLConnection = ssl.SSLConnection

local ltn12 = require("ltn12")
local type Pump = ltn12.Pump
local type Sink = ltn12.Sink
local type Source = ltn12.Source

local record https
   record HTTPSRequest
      -- HTTP options
      url: string|{string}
      sink: Sink<string>
      method: string
      headers: {string:string}
      source: Source<string>
      step: Pump<string>
      -- proxy: string -- not supported
      -- redirect: boolean -- not supported
      -- create: function -- https implements its own

      -- SSL options
      mode: string
      protocol: string
      key: string
      password: string|function
      certificate: string
      certificates: {SSLCertificate}
      cafile: string
      capath: string
      verify: string|{string}
      options: string|{string}
      ciphers: string
      ciphersuites: string
      depth: number
      dhparam: function
      curve: string
      curves_list: string
      verifyext: string|{string}
      alpn: string|function|{string}
      dane: boolean
   end
   request: function(string): string, number, {string:string}, string
   request: function(string, string): string, number, {string:string}, string
   request: function(HTTPSRequest): string, number, {string:string}, string
   tcp: function(): function(): SSLConnection
end

return https
