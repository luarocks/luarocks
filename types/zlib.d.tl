local record zlib
    _VERSION: string
    deflate: function(integer, integer): function(string, string): string
    inflate: function(integer): function(string): string
    crc32: function(): function(string): integer
    compress: function(string, integer, integer, integer): string
    decompress: function(string, integer): string
    crc32: function((function(string): integer), string): integer
end
return zlib