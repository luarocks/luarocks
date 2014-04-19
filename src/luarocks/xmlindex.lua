
--- Module which builds the index.xml page to be used in rocks servers.
local xmlindex = {}
package.loaded["luarocks.xmlindex"] = xmlindex

local util = require("luarocks.util")
local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local persist = require("luarocks.persist")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")

local index_header = [[
<?xml version="1.0" encoding="iso-8859-1"?>
<?xml-stylesheet type="text/xsl" href="view.xsl"?>
<repository>
]]

local index_footer = [[
</repository>
]]

local xsl = [===[
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">

<xsl:output method="html"
  encoding="iso-8859-1"
  doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
  doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" />

<xsl:template match="repository">
  <html>
    <head>
      <title>Available rocks</title>
      <style type="text/css"><![CDATA[
body {
   background-color: white;
   font-family: "bitstream vera sans", "verdana", "sans";
   font-size: 14px;
}
a {
   color: #0000c0;
   text-decoration: none;
}
a.pkg {
   color: black;
}
a:hover {
   text-decoration: underline;
}
div.main {
   font-size: 12px;
   margin-left: 40px;
   margin-right: 40px;
}
div.main div {
  margin-top: 12px;
  margin-bottom: 12px;
}
table {
  border-spacing: 2px 8px;
}
td.package {
   background-color: #f0f0f0;
   vertical-align: top;
}
td.version {
   background-color: #d0d0d0;
   vertical-align: top;
   text-align: left;
   padding: 5px;
   width: 100px;
}
div.manifest {
   font-size: 8px;
}
]]></style>
    </head>
    <body>
      <h1>Available rocks</h1>
      <div>Lua modules available from this location for use with <a href="http://www.luarocks.org/">LuaRocks</a>:</div>
      <table class="main">
        <xsl:apply-templates select="package" />
      </table>
      <div class="manifest">
        <a href="manifest">manifest file</a>
        <xsl:apply-templates select="luaversions/v" />
      </div>
    </body>
  </html>
</xsl:template>

<xsl:template match="v">
  <xsl:text> &#8226; </xsl:text><a>
    <xsl:attribute name="href">manifest-<xsl:value-of select="@version" /></xsl:attribute>
    Lua <xsl:value-of select="@version" /> manifest file</a>
  (<a><xsl:attribute name="href">manifest-<xsl:value-of select="@version" />.zip</xsl:attribute>zip</a><xsl:text>)</xsl:text>
</xsl:template>

<xsl:template match="package">
  <tr>
    <td class="package">
      <div>
        <a>
          <xsl:attribute name="id"><xsl:value-of select="@name" /></xsl:attribute>
          <xsl:attribute name="name"><xsl:value-of select="@name" /></xsl:attribute>
        </a>
        <a>
          <xsl:attribute name="class">pkg</xsl:attribute>
          <xsl:attribute name="href">#<xsl:value-of select="@name" /></xsl:attribute>
          <b><xsl:apply-templates select="rname" /></b>
        </a> - <xsl:apply-templates select="summary" />
      </div>
      <div class="main">
        <div><xsl:apply-templates select="detailed/*" mode="copy" /></div>
        <xsl:apply-templates select="externaldeps" />
        <div>
          <font size="-1">
            <a>
              <xsl:attribute name="href"><xsl:value-of select="source/@href" /></xsl:attribute>
              latest sources
            </a> <xsl:apply-templates select="homepage" /> | License: <xsl:choose>
            <xsl:when test="license"><xsl:apply-templates select="license" /></xsl:when>
            <xsl:otherwise>N/A</xsl:otherwise>
          </xsl:choose></font>
        </div>
      </div>
    </td>
    <td class="version">
      <xsl:apply-templates select="releases/r" />
    </td>
  </tr>
</xsl:template>

<xsl:template match="@* | node()" mode="copy">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()" />
  </xsl:copy>
</xsl:template>

<xsl:template match="externaldeps">
  <xsl:if test="count(dep) > 0">
    <div>
      <b>External dependencies:</b>&#160;<xsl:apply-templates select="dep" />
    </div>
  </xsl:if>
</xsl:template>

<xsl:template match="dep">
  <xsl:choose>
    <xsl:when test="platform">
      <xsl:choose>
        <xsl:when test="position()!=last()"><xsl:apply-templates select="platform" /></xsl:when>
        <xsl:otherwise><xsl:apply-templates select="platform" mode="last" /></xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="@name" /><xsl:if test="position()!=last()">,&#160;</xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="platform">
  <xsl:value-of select="../@name" /> (on <xsl:value-of select="text()" />),&#160;
</xsl:template>
<xsl:template match="platform" mode="last">
  <xsl:value-of select="../@name" /> (on <xsl:value-of select="text()" />)<xsl:if test="position()!=last()">,&#160;</xsl:if>
</xsl:template>

<xsl:template match="homepage">
  | <a target="_blank"><xsl:attribute name="href"><xsl:value-of select="@href" /></xsl:attribute>project homepage</a>
</xsl:template>

<xsl:template match="r">
  <div><xsl:value-of select="@version" />:<xsl:apply-templates select="rockspec|rock" /></div>
</xsl:template>

<xsl:template match="rockspec">
  <xsl:text>&#160;</xsl:text><a>
    <xsl:attribute name="href"><xsl:value-of select="../../../@name" />-<xsl:value-of select="../@version" />.rockspec</xsl:attribute>rockspec</a><xsl:if test="position()!=last()">,</xsl:if>
</xsl:template>

<xsl:template match="rock">
  <xsl:text>&#160;</xsl:text><a>
    <xsl:attribute name="href"><xsl:value-of select="../../../@name" />-<xsl:value-of select="../@version" />.<xsl:value-of select="@arch" />.rock</xsl:attribute><xsl:value-of select="@arch" /></a><xsl:if test="position()!=last()">,</xsl:if>
</xsl:template>

</xsl:stylesheet>
]===]


local function escape( s )
   return "<![CDATA["..s:gsub( "%]%]%>", "]]>]]&gt;<![CDATA[" ).."]]>"
end


local function richtext( s )
  s = s:gsub( "^%s*(.-)%s*$", "%1" )
  s = s:gsub( "%]%]%>", "]]>]]&gt;<![CDATA[" )
  s = s:gsub( "%s*\n\n%s*", "]]></p><p><![CDATA[" )
  s = s:gsub( "%s+", " " )
  return "<p><![CDATA["..s.."]]></p>"
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
   local out = assert( io.open(dir.path(repo, "index.xml"), "w") )

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
            out:write( "  <detailed>", richtext( descript.detailed ), "</detailed>\n" )
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
   out:write( "<luaversions>\n" )
   for ver in util.lua_versions() do
      out:write( "  <v version=\"", ver, "\" />\n" )
   end
   out:write( "</luaversions>\n" )
   out:write(index_footer)
   out:close()
   local out = assert( io.open(dir.path(repo, "view.xsl"), "w") )
   out:write(xsl)
   out:close()
   return true
end

return xmlindex

