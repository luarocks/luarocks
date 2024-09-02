
local record ltn12
    type Filter = function(string): string, string
    type Sink = function(string, string): boolean, string
    type Source = function(): string, string
 
    type FancySink = function(string, string): boolean, string | FancySink
    type FancySource = function(): string, string | FancySource
 
    -- Docs just say returns a truthy value on success
    -- Since this value should really only be
    -- used to check for truthiness, any seems fine here
    type Pump = function(Source, Sink): any, string
 
    record filter
       chain: function(Filter, Filter, ...: Filter): Filter
 
       cycle: function(string, string, any): Filter
    end
    record pump
       all: Pump
       step: Pump
    end
    record sink
       chain: function(Filter, Sink): Sink
       error: function(string): Sink
       file: function(FILE, string): Sink
       null: function(): Sink
       simplify: function(FancySink): Sink
       table: function({string}): Sink, {string}
    end
    record source
       cat: function(Source, ...: Source): Source
       chain: function(Source, Filter): Source
       empty: function(): Source
       error: function(string): Source
       file: function(FILE): Source
       file: function(FILE, string): Source
       simplify: function(FancySource): Source
       string: function(string): Source
       table: function({string}): Source, {string}
    end
 end
 
 return ltn12