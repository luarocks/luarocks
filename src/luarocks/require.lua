--- Retained for compatibility reasons only. Use luarocks.loader instead.
local require, pairs = require, pairs
module("luarocks.require")
for k,v in pairs(require("luarocks.loader")) do
   _M[k] = v
end
