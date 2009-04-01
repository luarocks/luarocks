
--- Build back-end for CMake-based modules.
module("luarocks.build.cmake", package.seeall)

local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")

--- Driver function for the "cmake" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors ocurred,
-- nil and an error message otherwise.
function run(rockspec)
   assert(type(rockspec) == "table")
   local build = rockspec.build
   local variables = build.variables or {}
   
   -- Pass Env variables
   build.variables.CMAKE_MODULE_PATH=os.getenv("CMAKE_MODULE_PATH")
   build.variables.CMAKE_LIBRARY_PATH=os.getenv("CMAKE_LIBRARY_PATH")
   build.variables.CMAKE_INCLUDE_PATH=os.getenv("CMAKE_INCLUDE_PATH")

   util.variable_substitutions(variables, rockspec.variables)
   
   -- If inline cmake is present create CMakeLists.txt from it.
   if type(build.cmake) == "string" then
      local cmake = assert(io.open(fs.current_dir().."/CMakeLists.txt", "w"))
      cmake:write(build.cmake)
      cmake:close()
   end


   -- Execute cmake with variables.
   local args = ""
   if cfg.cmake_generator then
      args = args .. ' -G"'..cfg.cmake_generator.. '"'
   end
   for k,v in pairs(variables) do
      args = args .. ' -D' ..k.. '="' ..v.. '"'
   end

   if not fs.execute("cmake . " ..args) then
      return nil, "Failed cmake."
   end
   
   if not fs.execute("make -fMakefile") then
      return nil, "Failed building."
   end

   if not fs.execute("make -fMakefile install") then
      return nil, "Failed installing."
   end
   return true
end
