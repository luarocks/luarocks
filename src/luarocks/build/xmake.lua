
--- Build back-end for xmake-based modules.
local xmake = {}

local fs      = require("luarocks.fs")
local util    = require("luarocks.util")
local dir     = require("luarocks.dir")
local path    = require("luarocks.path")
local cfg     = require("luarocks.core.cfg")
local builtin = require("luarocks.build.builtin")

-- from builtin.autoextract_libs
local function autoextract_libs(external_dependencies, variables)
   if not external_dependencies then
      return nil, nil, nil
   end
   local libs = {}
   local incdirs = {}
   local libdirs = {}
   for name, data in pairs(external_dependencies) do
      if data.library then
         table.insert(libs, data.library)
         table.insert(incdirs, variables[name .. "_INCDIR"])
         table.insert(libdirs, variables[name .. "_LIBDIR"])
      end
   end
   return libs, incdirs, libdirs
end

-- add platform configuration
local function add_platform_configs(info, rockspec, name)
   local variables = rockspec.variables

   -- add lua library
   info.incdirs   = info.incdirs or {}
   info.libdirs   = info.libdirs or {}
   info.libraries = info.libraries or {}
   info._cflags   = info._cflags or {}
   info._shflags  = info._shflags or {}
   table.insert(info.incdirs, variables.LUA_INCDIR)
   table.insert(info._cflags, variables.CFLAGS)
   table.insert(info._shflags, variables.LIBFLAG)

   -- add platform configuration
   if cfg.is_platform("mingw32") then
   elseif cfg.is_platform("win32") then
      local deffile = name .. ".def"
      local def = io.open(dir.path(fs.current_dir(), deffile), "w+")
      local exported_name = name:gsub("%.", "_")
      exported_name = exported_name:match('^[^%-]+%-(.+)$') or exported_name
      def:write("EXPORTS\n")
      def:write("luaopen_"..exported_name.."\n")
      def:close()
      table.insert(info._shflags, "-def:" .. deffile)
   else
      if cfg.link_lua_explicitly then
        table.insert(info.libdirs, variables.LUA_LIBDIR)
        table.insert(info.libraries, "lua")
      end
   end
end

-- Generate xmake.lua from builtin source files
local function autogen_xmakefile(xmakefile, rockspec)

   -- Patch build
   local build = rockspec.build
   if not build.modules then
      if rockspec:format_is_at_least("3.0") then
         local libs, incdirs, libdirs = autoextract_libs(rockspec.external_dependencies, rockspec.variables)
         local install, copy_directories
         build.modules, install, copy_directories = builtin.autodetect_modules(libs, incdirs, libdirs)
         build.install = build.install or install
         build.copy_directories = build.copy_directories or copy_directories
      else
         return nil, "Missing build.modules table"
      end
   end

   -- Check lua.h
   local variables = rockspec.variables
   local lua_incdir, lua_h = variables.LUA_INCDIR, "lua.h"
   if not fs.exists(dir.path(lua_incdir, lua_h)) then
      return nil, "Lua header file " .. lua_h .. " not found (looked in " .. lua_incdir .. "). \n"  .. 
                  "You need to install the Lua development package for your system."
   end

   -- Generate xmake.lua
   local build_sources = false
   local file = assert(io.open(xmakefile, "w"))
   file:write('add_rules("mode.release", "mode.debug")\n')
   for name, info in pairs(build.modules) do
      if type(info) == "string" then
         local ext = info:match("%.([^.]+)$")
         if ext ~= "lua" then
            info = {info}
         end
      end
      if type(info) == "table" then
         local sources = info.sources
         if info[1] then sources = info end
         if type(sources) == "string" then sources = {sources} end
         if #sources > 0 then
             build_sources = true
             local module_name = name:match("([^.]*)$") .. "." .. util.matchquote(cfg.lib_extension)
             file:write('target("' .. name .. '")\n')
             if cfg.is_platform("macosx") then
                file:write('    set_kind("binary")\n')
             else
                file:write('    set_kind("shared")\n')
             end
             file:write('    set_filename("' .. module_name .. '")\n')
             add_platform_configs(info, rockspec, name)
             for _, source in ipairs(sources) do
                file:write("    add_files('" .. source .. "')\n")
             end
             if info.defines then
                for _, define in ipairs(info.defines) do
                   file:write("    add_defines('" .. define .. "')\n")
                end
             end
             if info.incdirs then
                for _, incdir in ipairs(info.incdirs) do
                   file:write("    add_includedirs('" .. incdir .. "')\n")
                end
             end
             if info.libdirs then
                for _, libdir in ipairs(info.libdirs) do
                   file:write("    add_linkdirs('" .. libdir .. "')\n")
                   if not cfg.is_platform("win32") and not cfg.is_platform("mingw32") and cfg.gcc_rpath then
                      file:write("    add_rpathdirs('" .. libdir .. "')\n")
                   end
                end
             end
             if info._cflags then
                for _, cflag in ipairs(info._cflags) do
                   file:write("    add_cflags('" .. cflag .. "', {force = true})\n")
                end
             end
             if info._shflags then
                for _, shflag in ipairs(info._shflags) do
                   if cfg.is_platform("macosx") then
                      file:write("    add_ldflags('" .. shflag .. "', {force = true})\n")
                   else
                      file:write("    add_shflags('" .. shflag .. "', {force = true})\n")
                   end
                end
             end
             if info.libraries then
                for _, library in ipairs(info.libraries) do
                   file:write("    add_links('" .. library .. "')\n")
                end
             end
             -- Install modules, e.g. socket.core -> lib/socket/core.so
             file:write("    on_install(function (target)\n")
             file:write("        local moduledir = path.directory((target:name():gsub('%.', '/')))\n")
             file:write("        import('target.action.install')(target, {libdir = path.join('lib', moduledir), bindir = path.join('lib', moduledir)})\n")
             file:write("    end)\n")
             file:write('\n')
         end
      end
   end
   file:close()
   if not build_sources then
     os.remove(xmakefile)
   end
   return true
end

--- Driver function for the "xmake" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors occurred,
-- nil and an error message otherwise.
function xmake.run(rockspec, no_install)

   -- Get rockspec
   assert(rockspec:type() == "rockspec")
   local build = rockspec.build

   -- Check xmake
   local xmake = rockspec.variables.XMAKE
   local ok, err_msg = fs.is_tool_available(xmake, "XMake")
   if not ok then
      return nil, err_msg
   end

   -- If inline xmake is present create xmake.lua from it.
   local xmakefile = fs.current_dir() .. "/xmake.lua"
   if type(build.xmake) == "string" then
      local file = assert(io.open(xmakefile, "w"))
      file:write(build.xmake)
      file:close()
   end

   -- Generate xmake.lua from builtin source files
   if not fs.is_file(xmakefile) then
      local ok, err_msg = autogen_xmakefile(xmakefile, rockspec)
      if not ok then
         return nil, err_msg
      end
   end

   -- We need not build it if xmake.lua not found (only install lua scripts)
   if not fs.is_file(xmakefile) then
      return true
   end

   -- Dump xmake.lua if be verbose mode
   if cfg.verbose then
      local file = io.open(xmakefile, "r")
      if file then
         print(file:read('a+'))
         file:close()
      end
   end

   -- Do configure
   local args = ""
   if cfg.is_platform("mingw32") then
      args = args .. " -p mingw"
   end
   if not fs.execute_string(xmake .. " f -y" .. args) then
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
      if not fs.execute_string(xmake .. (cfg.verbose and " -vD" or "")) then
         return nil, "Failed building."
      end
   end
   if do_install and not no_install then
      if not fs.execute_string(xmake .. " install -y -o output") then
         return nil, "Failed installing."
      end
   end

   local libdir = path.lib_dir(rockspec.name, rockspec.version)
   fs.copy_contents(dir.path("output", "lib"), libdir, "exec")

   return true
end

return xmake
