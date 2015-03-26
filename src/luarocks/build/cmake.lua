
--- Build back-end for CMake-based modules.
--module("luarocks.build.cmake", package.seeall)
local cmake = {}

local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")

--- Driver function for the "cmake" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors ocurred,
-- nil and an error message otherwise.
function cmake.run(rockspec)
   assert(type(rockspec) == "table")
   local build = rockspec.build
   local variables = build.variables or {}

   -- Pass Env variables
   variables.CMAKE_MODULE_PATH=os.getenv("CMAKE_MODULE_PATH")
   variables.CMAKE_LIBRARY_PATH=os.getenv("CMAKE_LIBRARY_PATH")
   variables.CMAKE_INCLUDE_PATH=os.getenv("CMAKE_INCLUDE_PATH")

   util.variable_substitutions(variables, rockspec.variables)

   if not fs.execute_quiet(rockspec.variables.CMAKE, "--help") then
      return nil, "'"..rockspec.variables.CMAKE.."' program not found. Is cmake installed? You may want to edit variables.CMAKE"
   end

   -- If inline cmake is present create CMakeLists.txt from it.
   if type(build.cmake) == "string" then
      local cmake_handler = assert(io.open(fs.current_dir().."/CMakeLists.txt", "w"))
      cmake_handler:write(build.cmake)
      cmake_handler:close()
   end


   -- Execute cmake with variables.
   local args = ""
   if cfg.cmake_generator then
      args = args .. ' -G"'..cfg.cmake_generator.. '"'
   end
   for k,v in pairs(variables) do
      args = args .. ' -D' ..k.. '="' ..v.. '"'
   end

   if not fs.execute_string(rockspec.variables.CMAKE.." -H. -Bbuild.luarocks "..args) then
      return nil, "Failed cmake."
   end

   if not fs.execute_string(rockspec.variables.CMAKE.." --build build.luarocks --config Release") then
      return nil, "Failed building."
   end

   if not fs.execute_string(rockspec.variables.CMAKE.." --build build.luarocks --target install --config Release") then
      return nil, "Failed installing."
   end
   return true
end

return cmake
