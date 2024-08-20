local type q = require("luarocks.core.types.query")
local type Query = q.Query

local type Tree = require("luarocks.core.types.tree").Tree

local record manifest      
   record Manifest
      record Entry
         arch: string
         commands: {string: string}
         dependencies: {string: string}
         modules: {string: string}
      end

      arch: string
      commands: {string: {string}}
      dependencies: {string: {string: {Query}}}
      modules: {string: {string}}
      repository: {string: {string: {Entry}}}
   end

   record Tree_manifest
      tree: Tree
      manifest: Manifest
   end
end

return manifest