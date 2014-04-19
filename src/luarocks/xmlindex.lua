
--- Module which builds the index.xml page to be used in rocks servers.
local xmlindex = {}
package.loaded["luarocks.xmlindex"] = xmlindex

local util = require("luarocks.util")
local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local persist = require("luarocks.persist")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")

local ext_url_target = ' target="_blank"'

local index_header = [[
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="view.xsl"?>
<repository>
]]

local index_footer = [[
</repository>
]]


local function escape( s )
   return "<![CDATA["..s:gsub( "%]%]%>", "]]>]]&gt;<![CDATA[" ).."]]>"
end


local function collect_external_dependencies(rockspec)
   local deplist = {}
   if rockspec.external_dependencies then
      local listed_set = {}
      local plats = nil
      for name, desc in util.sortedpairs(rockspec.external_dependencies) do
         if name ~= "platforms" then
            table.insert(deplist, { name:lower( ) })
            listed_set[name] = true
         else
            plats = desc
         end
      end
      if plats then
         for plat, entries in util.sortedpairs(plats) do
            for name, desc in util.sortedpairs(entries) do
               if not listed_set[name] then
                  local lname = name:lower()
                  local idx = deplist[lname] or #deplist+1
                  local ndep = deplist[idx] or { lname }
                  deplist[idx] = ndep
                  deplist[lname] = idx
                  table.insert(ndep, plat )
               end
            end
         end
      end
   end
   return deplist
end

function xmlindex.make_index(repo)
   if not fs.is_dir(repo) then
      return nil, "Cannot access repository at "..repo
   end
   local manifest = manif.load_manifest(repo)
   local out = io.open(dir.path(repo, "index.xml"), "w")

   out:write(index_header)
   for package, version_list in util.sortedpairs(manifest.repository) do
      local latest_rockspec = nil
      out:write( "<package name=\"", package, "\">\n  <releases>\n" )
      for version, data in util.sortedpairs(version_list, deps.compare_versions) do
         out:write( "    <r version=\"", version, "\">\n" )
         table.sort(data, function(a,b) return a.arch < b.arch end)
         for _, item in ipairs(data) do
            if item.arch == 'rockspec' then
               out:write( "      <rockspec />\n" )
               if not latest_rockspec then
                 latest_rockspec = ("%s-%s.rockspec"):format(package, version)
               end
            else
               out:write( "      <rock arch=\"", item.arch, "\" />\n" )
            end
         end
         out:write( "    </r>\n" )
      end
      out:write( "  </releases>\n" )
      if latest_rockspec then
         local rockspec = persist.load_into_table(dir.path(repo, latest_rockspec))
         local descript = rockspec.description or {}
         out:write( "  <rname>", rockspec.package, "</rname>\n" )
         out:write( "  <source href=\"", rockspec.source.url, "\" />\n" )
         if descript.summary then
            local stripped = descript.summary:gsub( "^%s*(.-)%s*$", "%1" )
            out:write( "  <summary>", escape( stripped ), "</summary>\n" )
         end
         if descript.detailed then
            local stripped = descript.detailed:gsub( "^%s*(.-)%s*$", "%1" )
            out:write( "  <detailed>", escape( stripped ), "</detailed>\n" )
         end
         if descript.license then
            out:write( "  <license>", escape( descript.license ), "</license>\n" )
         end
         if descript.homepage then
            out:write( "  <homepage href=\"", descript.homepage, "\" />\n" )
         end
         out:write( "  <externaldeps>\n" )
         for _,d in ipairs(collect_external_dependencies(rockspec)) do
            out:write( "    <dep name=\"", d[1], "\"" )
            if #d > 1 then
               out:write( ">\n" )
               for i = 2, #d do
                  out:write( "      <platform>", d[i], "</platform>\n" )
               end
               out:write( "    </dep>\n" )
            else
               out:write( " />\n" )
            end
         end
         out:write( "  </externaldeps>\n" )
      end
      out:write( "</package>\n" )
   end
   out:write(index_footer)
   out:close()
   return true
end

return xmlindex

