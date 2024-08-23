local socket = require("socket")
local TCP = socket.TCP

local record ssl
   record SSLCertificate
      certificate: string
      key: string
      password: string|function
   end
   record SSLContext
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
   record X509Certificate
      enum Algorithm
         "sha1"
         "sha256"
         "sha512"
      end
      digest: function(X509Certificate, Algorithm): string
      extensions: function(X509Certificate): {string}
      issued: function(X509Certificate, X509Certificate): string
      issuer: function(X509Certificate): string
      notbefore: function(X509Certificate): string
      notafter: function(X509Certificate): string
      pem: function(X509Certificate): string
      pubkey: function(X509Certificate): string
      serial: function(X509Certificate): string
      enum Encoding
         "ai5"
         "utf8"
      end
      setencode: function(X509Certificate, Encoding): string
      subject: function(X509Certificate): string
      validat: function(X509Certificate, string): boolean
   end
   record SSLConnection
      close: function(SSLConnection)
      dohandshake: function(SSLConnection): boolean, string
      getalpn: function(SSLConnection): string
      getfinished: function(SSLConnection): string
      getpeercertificate: function(SSLConnection): X509Certificate
      getpeercertificate: function(SSLConnection, number): X509Certificate
      getpeerchain: function(SSLConnection): X509Certificate
      getpeerverification: function(SSLConnection): string
      getpeerfinished: function(SSLConnection): string
      getsniname: function(SSLConnection): string
      getstats: function(SSLConnection): number, number, number
      info: function(SSLConnection): table
      info: function(SSLConnection, string): string
      enum ReceivePattern
         "*a"
         "*l"
      end
      receive: function(SSLConnection, number|ReceivePattern): string, string
      receive: function(SSLConnection, number|ReceivePattern, string): string, string
      send: function(SSLConnection): number, number|string, number
      send: function(SSLConnection, number): number, number|string, number
      send: function(SSLConnection, number, number): number, number|string, number
      setdane: function(SSLConnection, string)
      setstats: function(SSLConnection, number, number, number): number
      enum TimeoutMode
         "b"
         "t"
      end
      settimeout: function(SSLConnection, number)
      settimeout: function(SSLConnection, number, TimeoutMode)
      settlsa: function(SSLConnection, number, number, number, number)
      sni: function(SSLConnection, string)
      sni: function(SSLConnection, {string:SSLContext})
      sni: function(SSLConnection, {string:SSLContext}, boolean)
      enum Reason
         "read"
         "write"
         "nothing"
      end
      want: function(SSLConnection): Reason
   end

   record config
      protocols: {string:boolean}
      curves: {string:boolean}
      capabilities: {string:boolean}
      options: {string:boolean}
      algorithms: {string:boolean}
   end

   newcontext: function(SSLContext): SSLContext
   wrap: function(TCP, SSLContext): SSLConnection
   loadcertificate: function(string): X509Certificate

   _COPYRIGHT: string
   _VERSION: string
end

return ssl