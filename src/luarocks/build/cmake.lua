local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local type = type



local cmake = { CMakeBuild = {} }










local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")







function cmake.run(rockspec, no_install)
   local build = rockspec.build
   local variables = build.variables or {}

   util.variable_substitutions(variables, rockspec.variables)

   local ok, err_msg = fs.is_tool_available(rockspec.variables.CMAKE, "CMake")
   if not ok then
      return nil, err_msg
   end


   local build_cmake = build.cmake
   if type(build_cmake) == "string" then
      local cmake_handler = assert((io.open(fs.current_dir() .. "/CMakeLists.txt", "w")))
      cmake_handler:write(build.cmake)
      cmake_handler:close()
   end


   local args = ""


   if cfg.cmake_generator then
      args = args .. ' -G"' .. cfg.cmake_generator .. '"'
   elseif cfg.is_platform("windows") and cfg.target_cpu:match("x86_64$") then
      args = args .. " -DCMAKE_GENERATOR_PLATFORM=x64"
   end

   for k, v in pairs(variables) do
      args = args .. ' -D' .. k .. '="' .. tostring(v) .. '"'
   end

   if not fs.execute_string(rockspec.variables.CMAKE .. " -H. -Bbuild.luarocks " .. args) then
      return nil, "Failed cmake."
   end

   local do_build, do_install
   if rockspec:format_is_at_least("3.0") then
      do_build = (build.build_pass == nil) and true or build.build_pass
      do_install = (build.install_pass == nil) and true or build.install_pass
   else
      do_build = true
      do_install = true
   end

   if do_build then
      if not fs.execute_string(rockspec.variables.CMAKE .. " --build build.luarocks --config Release") then
         return nil, "Failed building."
      end
   end
   if do_install and not no_install then
      if not fs.execute_string(rockspec.variables.CMAKE .. " --build build.luarocks --target install --config Release") then
         return nil, "Failed installing."
      end
   end

   return true
end

return cmake
