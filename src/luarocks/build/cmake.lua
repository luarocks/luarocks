
--- Build back-end for CMake-based modules.
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

   local ok, err_msg = fs.is_tool_available(rockspec.variables.CMAKE, "CMake")
   if not ok then
      return nil, err_msg
   end

   -- If inline cmake is present create CMakeLists.txt from it.
   if type(build.cmake) == "string" then
      local cmake_handler = assert(io.open(fs.current_dir().."/CMakeLists.txt", "w"))
      cmake_handler:write(build.cmake)
      cmake_handler:close()
   end

   -- Execute cmake with variables.
   local args = ""
   
   -- Try to pick the best generator. With msvc and x64, CMake does not select it by default so we need to be explicit.
   if cfg.cmake_generator then
      args = args .. ' -G"'..cfg.cmake_generator.. '"'
   elseif cfg.is_platform("windows") and cfg.target_cpu:match("x86_64$") then
      args = args .. " -DCMAKE_GENERATOR_PLATFORM=x64"
   end

   for k,v in pairs(variables) do
      args = args .. ' -D' ..k.. '="' ..tostring(v).. '"'
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
