
--- A builtin build system: back-end to provide a portable way of building C-based Lua modules.
--module("luarocks.build.builtin", package.seeall)
local builtin = {}

local unpack = unpack or table.unpack

local fs = require("luarocks.fs")
local path = require("luarocks.path")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

--- Run a command displaying its execution on standard output.
-- @return boolean: true if command succeeds (status code 0), false
-- otherwise.
local function execute(...)
   io.stdout:write(table.concat({...}, " ").."\n")
   return fs.execute(...)
end

--- Makes an RC file with an embedded Lua script, for building .exes on Windows
-- @return nil if could open files, error otherwise
local function make_rc(luafilename, rcfilename)
   --TODO EXEWRAPPER
   local rcfile = io.open(rcfilename, "w")
   if not rcfile then
      error("Could not open "..rcfilename.." for writing.")
   end
   rcfile:write("STRINGTABLE\r\nBEGIN\r\n")

   local i = 1
   for line in io.lines(luafilename) do
      if not line:match("^#!") then
         rcfile:write(i .. " \"")
         line = line:gsub("\\", "\\\\"):gsub('"', '""'):gsub("[\r\n]+", "")
         rcfile:write(line .. "\\r\\n\"\r\n")
         i = i + 1
      end
   end

   rcfile:write("END\r\n")

   rcfile:close()
end

--- Driver function for the builtin build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors ocurred,
-- nil and an error message otherwise.
function builtin.run(rockspec)
   assert(type(rockspec) == "table")
   local compile_object, compile_library, compile_wrapper_binary --TODO EXEWRAPPER

   local build = rockspec.build
   local variables = rockspec.variables

   local function add_flags(extras, flag, flags)
      if flags then
         if type(flags) ~= "table" then
            flags = { tostring(flags) }
         end
         util.variable_substitutions(flags, variables)
         for _, v in ipairs(flags) do
            table.insert(extras, flag:format(v))
         end
      end
   end

   if cfg.is_platform("mingw32") then
      compile_object = function(object, source, defines, incdirs)
         local extras = {}
         add_flags(extras, "-D%s", defines)
         add_flags(extras, "-I%s", incdirs)
         return execute(variables.CC.." "..variables.CFLAGS, "-c", "-o", object, "-I"..variables.LUA_INCDIR, source, unpack(extras))
      end
      compile_library = function(library, objects, libraries, libdirs)
         local extras = { unpack(objects) }
         add_flags(extras, "-L%s", libdirs)
         add_flags(extras, "-l%s", libraries)
         extras[#extras+1] = dir.path(variables.LUA_LIBDIR, variables.LUALIB)
         extras[#extras+1] = "-l" .. (variables.MSVCRT or "m")
         local ok = execute(variables.LD.." "..variables.LIBFLAG, "-o", library, unpack(extras))
         return ok
      end
      compile_wrapper_binary = function(fullname, name)
         --TODO EXEWRAPPER
         local fullbasename = fullname:gsub("%.lua$", ""):gsub("/", "\\")
         local basename = name:gsub("%.lua$", ""):gsub("/", "\\")
         local rcname = basename..".rc"
         local resname = basename..".o"
         local wrapname = basename..".exe"
         make_rc(fullname, fullbasename..".rc")
         local ok = execute(variables.RC, "-o", resname, rcname)
         if not ok then return ok end
         ok = execute(variables.CC.." "..variables.CFLAGS, "-I"..variables.LUA_INCDIR,
                      "-o", wrapname, resname, variables.WRAPPER,
                      dir.path(variables.LUA_LIBDIR, variables.LUALIB),
                      "-l" .. (variables.MSVCRT or "m"), "-luser32")
         return ok, wrapname
      end
   elseif cfg.is_platform("win32") then
      compile_object = function(object, source, defines, incdirs)
         local extras = {}
         add_flags(extras, "-D%s", defines)
         add_flags(extras, "-I%s", incdirs)
         return execute(variables.CC.." "..variables.CFLAGS, "-c", "-Fo"..object, "-I"..variables.LUA_INCDIR, source, unpack(extras))
      end
      compile_library = function(library, objects, libraries, libdirs, name)
         local extras = { unpack(objects) }
         add_flags(extras, "-libpath:%s", libdirs)
         add_flags(extras, "%s.lib", libraries)
         local basename = dir.base_name(library):gsub(".[^.]*$", "")
         local deffile = basename .. ".def"
         local def = io.open(dir.path(fs.current_dir(), deffile), "w+")
         def:write("EXPORTS\n")
         def:write("luaopen_"..name:gsub("%.", "_").."\n")
         def:close()
         local ok = execute(variables.LD, "-dll", "-def:"..deffile, "-out:"..library, dir.path(variables.LUA_LIBDIR, variables.LUALIB), unpack(extras))
         local basedir = ""
         if name:find("%.") ~= nil then
            basedir = name:gsub("%.%w+$", "\\")
            basedir = basedir:gsub("%.", "\\")
         end
         local manifestfile = basedir .. basename..".dll.manifest"

         if ok and fs.exists(manifestfile) then
            ok = execute(variables.MT, "-manifest", manifestfile, "-outputresource:"..basedir..basename..".dll;2")
         end
         return ok
      end
      compile_wrapper_binary = function(fullname, name)
         --TODO EXEWRAPPER
         local fullbasename = fullname:gsub("%.lua$", ""):gsub("/", "\\")
         local basename = name:gsub("%.lua$", ""):gsub("/", "\\")
         local object = basename..".obj"
         local rcname = basename..".rc"
         local resname = basename..".res"
         local wrapname = basename..".exe"
         make_rc(fullname, fullbasename..".rc")
         local ok = execute(variables.RC, "-r", "-fo"..resname, rcname)
         if not ok then return ok end
         ok = execute(variables.CC.." "..variables.CFLAGS, "-c", "-Fo"..object,
                      "-I"..variables.LUA_INCDIR, variables.WRAPPER)
         if not ok then return ok end
         ok = execute(variables.LD, "-out:"..wrapname, resname, object,
                      dir.path(variables.LUA_LIBDIR, variables.LUALIB), "user32.lib")
         local manifestfile = wrapname..".manifest"
         if ok and fs.exists(manifestfile) then
            ok = execute(variables.MT, "-manifest", manifestfile, "-outputresource:"..wrapname..";1")
         end
         return ok, wrapname
      end
   else
      compile_object = function(object, source, defines, incdirs)
         local extras = {}
         add_flags(extras, "-D%s", defines)
         add_flags(extras, "-I%s", incdirs)
         return execute(variables.CC.." "..variables.CFLAGS, "-I"..variables.LUA_INCDIR, "-c", source, "-o", object, unpack(extras))
      end
      compile_library = function (library, objects, libraries, libdirs)
         local extras = { unpack(objects) }
         add_flags(extras, "-L%s", libdirs)
         if cfg.gcc_rpath then
            add_flags(extras, "-Wl,-rpath,%s:", libdirs)
         end
         add_flags(extras, "-l%s", libraries)
         if cfg.is_platform("cygwin") then
            add_flags(extras, "-l%s", {"lua"})
         end
         return execute(variables.LD.." "..variables.LIBFLAG, "-o", library, "-L"..variables.LUA_LIBDIR, unpack(extras))
      end
      compile_wrapper_binary = function(_, name) return true, name end
      --TODO EXEWRAPPER
   end

   local ok = true
   local built_modules = {}
   local luadir = path.lua_dir(rockspec.name, rockspec.version)
   local libdir = path.lib_dir(rockspec.name, rockspec.version)
   --TODO EXEWRAPPER
   -- On Windows, compiles an .exe for each Lua file in build.install.bin, and
   -- replaces the filename with the .exe name. Strips the .lua extension if it exists,
   -- otherwise just appends .exe to the name. Only if `cfg.exewrapper = true`
   if build.install and build.install.bin then
     for key, name in pairs(build.install.bin) do
       local fullname = dir.path(fs.current_dir(), name)
       if cfg.exewrapper and fs.is_lua(fullname) then
          ok, name = compile_wrapper_binary(fullname, name)
          if ok then
             build.install.bin[key] = name
          else
             return nil, "Build error in wrapper binaries"
          end
       end
     end
   end
   
   if not build.modules then
      return nil, "Missing build.modules table"
   end
   for name, info in pairs(build.modules) do
      local moddir = path.module_to_path(name)
      if type(info) == "string" then
         local ext = info:match(".([^.]+)$")
         if ext == "lua" then
            local filename = dir.base_name(info)
            if info:match("init%.lua$") and not name:match("%.init$") then
               moddir = path.module_to_path(name..".init")
            else
               local basename = name:match("([^.]+)$")
               local baseinfo = filename:gsub("%.lua$", "")
               if basename ~= baseinfo then
                  filename = basename..".lua"
               end
            end
            local dest = dir.path(luadir, moddir, filename)
            built_modules[info] = dest
         else
            info = {info}
         end
      end
      if type(info) == "table" then
         local objects = {}
         local sources = info.sources
         if info[1] then sources = info end
         if type(sources) == "string" then sources = {sources} end
         for _, source in ipairs(sources) do
            local object = source:gsub(".[^.]*$", "."..cfg.obj_extension)
            if not object then
               object = source.."."..cfg.obj_extension
            end
            ok = compile_object(object, source, info.defines, info.incdirs)
            if not ok then
               return nil, "Failed compiling object "..object
            end
            table.insert(objects, object)
         end
         if not ok then break end
         local module_name = name:match("([^.]*)$").."."..util.matchquote(cfg.lib_extension)
         if moddir ~= "" then
            module_name = dir.path(moddir, module_name)
            local ok, err = fs.make_dir(moddir)
            if not ok then return nil, err end
         end
         built_modules[module_name] = dir.path(libdir, module_name)
         ok = compile_library(module_name, objects, info.libraries, info.libdirs, name)
         if not ok then
            return nil, "Failed compiling module "..module_name
         end
      end
   end
   for name, dest in pairs(built_modules) do
      fs.make_dir(dir.dir_name(dest))
      ok = fs.copy(name, dest)
      if not ok then
         return nil, "Failed installing "..name.." in "..dest
      end
   end
   if fs.is_dir("lua") then
      local ok, err = fs.copy_contents("lua", luadir)
      if not ok then
         return nil, "Failed copying contents of 'lua' directory: "..err
      end
   end
   return true
end

return builtin
