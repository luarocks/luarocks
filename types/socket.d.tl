local ltn12 = require("ltn12")
local type Sink = ltn12.Sink
local type Source = ltn12.Source

local record socket
   record TCP
      -- master methods
      bind: function(TCP, string, integer)
      connect: function(TCP, string, integer): integer, string
      listen: function(TCP, integer): integer, string

      -- client methods
      getpeername: function(TCP): string, integer

      enum TCPReceivePattern
         "*l"
         "*a"
      end
      enum TCPReceiveError
         "closed"
         "timeout"
      end
      receive: function(TCP, TCPReceivePattern|integer, string): string, TCPReceiveError

      send: function(TCP, string, integer, integer): integer, string, integer

      enum TCPShutdownMode
         "both"
         "send"
         "receive"
      end
      shutdown: function(TCP, TCPShutdownMode): integer

      -- server methods
      accept: function(TCP): TCP, string

      -- client and server methods
      enum TCPOption
         "keepalive"
         "reuseaddr"
         "tcp-nodelay"
      end
      enum TCPLinger
         "linger"
      end
      record TCPLingerOption
         on: boolean
         timeout: integer
      end
      setoption: function(TCP, TCPOption): integer
      setoption: function(TCP, TCPLinger, TCPLingerOption): integer

      -- master, client, and server methods
      close: function(TCP)

      getsockname: function(TCP): string, integer

      getstats: function(TCP): integer, integer, integer

      setstats: function(TCP, integer, integer, integer): integer

      enum TCPTimeoutMode
         "b"
         "t"
      end
      settimeout: function(TCP, integer, TCPTimeoutMode)
   end
   record UDP
      close: function(UDP)

      getpeername: function(UDP): string, integer

      getsockname: function(UDP): string, integer

      enum UDPTimeout
         "timeout"
      end
      receive: function(UDP, integer): string, UDPTimeout

      receivefrom: function(UDP, integer): string, string, integer, UDPTimeout

      send: function(UDP, string): integer, string

      sendto: function(UDP, string, string, integer): integer, string

      setpeername: function(UDP, string, integer): integer, string

      setsockname: function(UDP, string, integer): integer, string

      enum UDPOptions
         "dontroute"
         "broadcast"
      end
      setoption: function(UDP, UDPOptions, boolean): integer, string

      settimeout: function(UDP, integer)
   end
   tcp: function(): TCP, string

   udp: function(): UDP, string

   record dns
      record DNSResolved
         name: string
         alias: {string}
         ip: {string}
      end
      toip: function(): string
      tohostname: function(string): string, DNSResolved|string
      gethostname: function(string): string, DNSResolved|string
   end

   bind: function(string, integer, integer): TCP

   connect: function(string, integer, string, integer): TCP

   _DEBUG: boolean

   newtry: function(function): function

   protect: function(function): function

   -- tagged records/Table Union types would be nice here,
   -- as this should be {TCP|UDP}
   -- but I imagine this should be fine for most uses
   select: function({UDP}, {UDP}, integer): {UDP}, {UDP}, string
   select: function({TCP}, {TCP}, integer): {TCP}, {TCP}, string

   enum SinkMode
      "http-chunked"
      "close-when-done"
      "keep-open"
   end

   sink: function(SinkMode, UDP): Sink
   sink: function(SinkMode, TCP): Sink

   skip: function(integer, ...: any): any...

   sleep: function(integer)

   enum SourceMode
      "http-chunked"
      "by-length"
      "until-closed"
   end

   source: function(SourceMode, TCP, integer): Source
   source: function(SourceMode, UDP, integer): Source

   gettime: function(): integer

   try: function(...: any): any...

   _VERSION: string
end

return socket
