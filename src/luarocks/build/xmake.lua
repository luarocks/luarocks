
--- Build back-end for xmake-based modules.
local xmake = {}

local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")

--- Driver function for the "xmake" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors occurred,
-- nil and an error message otherwise.
function xmake.run(rockspec, no_install)
   assert(rockspec:type() == "rockspec")
   local build = rockspec.build
   local variables = build.variables or {}

   util.variable_substitutions(variables, rockspec.variables)

   local ok, err_msg = fs.is_tool_available(rockspec.variables.XMAKE, "XMake")
   if not ok then
      return nil, err_msg
   end

   -- If inline xmake is present create xmake.lua from it.
   if type(build.xmake) == "string" then
      local xmake_handler = assert(io.open(fs.current_dir().."/xmake.lua", "w"))
      xmake_handler:write(build.xmake)
      xmake_handler:close()
   end

   -- Do configure
  if not fs.execute_string(rockspec.variables.XMAKE.. " f -y") then
     return nil, "Failed configuring."
  end

   -- Do build and install
   local do_build, do_install
   if rockspec:format_is_at_least("3.0") then
      do_build   = (build.build_pass   == nil) and true or build.build_pass
      do_install = (build.install_pass == nil) and true or build.install_pass
   else
      do_build = true
      do_install = true
   end

   if do_build then
      if not fs.execute_string(rockspec.variables.XMAKE) then
         return nil, "Failed building."
      end
   end
   if do_install and not no_install then
      if not fs.execute_string(rockspec.variables.XMAKE.." install -y -o output") then
         return nil, "Failed installing."
      end
   end

   build.install.lib = build.install.lib or {}
   local files = fs.list_dir("output/lib")
   for _, filename in pairs(files) do
       table.insert(build.install.lib, "output/lib/" .. filename)
   end

   return true
end

return xmake
