local type query = require("luarocks.core.types.query")
local type Query = query.Query

local type tree = require("luarocks.core.types.tree")
local type Tree = tree.Tree

local record manifest
    record Manifest
       arch: string
       commands: {string: {string}}
       dependencies: {string: {string: {Query}}}
       modules: {string: {string}}
       repository: {string: {string: {Manifest}}}
    end
    
    record Tree_manifest
       tree: Tree
       manifest: Manifest
    end
 end

 return manifest