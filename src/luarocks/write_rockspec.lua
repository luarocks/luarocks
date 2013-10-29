
module("luarocks.write_rockspec", package.seeall)

local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local persist = require("luarocks.persist")
local type_check = require("luarocks.type_check")
local util = require("luarocks.util")

help_summary = "Write a template for a rockspec file."
help_arguments = "[--output=<file> ...] [<name>] [<version>] {<url>|<path>}"
help = [[
This command writes an initial version of a rockspec file,
based on an URL or a local path. You may use a relative path such as '.'.
If a local path is given, name and version arguments are mandatory.
For URLs, LuaRocks will attempt to infer name and version if not given.

If a repository URL is given with no version, it creates an 'scm' rock.

Note that the generated file is a _starting point_ for writing a
rockspec, and is not guaranteed to be complete or correct.

--output=<file>       Write the rockspec with the given filename.
                      If not given, a file is written in the current
                      directory with a filename based on given name and version.
--license="<string>"  A license string, such as "MIT/X11" or "GNU GPL v3".
--summary="<txt>"     A short one-line description summary.
--description="<txt>" A longer description string.
--homepage=<url>      Project homepage.
--lua-version=<ver>   Supported Lua versions. Accepted values are "5.1", "5.2"
                      or "5.1,5.2".
--lib=<lib>[,<lib>]   A comma-separated list of libraries that C files need to
                      link to.
]]


local function get_url(rockspec)
   local url = rockspec.source.url
   local file, temp_dir, err_code, err_file, err_temp_dir = fetch.fetch_sources(rockspec, false)
   if err_code == "source.dir" then
      file, temp_dir = err_file, err_temp_dir
   elseif not file then
      util.warning("Could not fetch sources - "..temp_dir)
      return false
   end
   util.printout("File successfully downloaded. Making checksum and checking base dir...")
   local md5 = nil
   if fetch.is_basic_protocol(rockspec.source.protocol) then
      rockspec.source.md5 = fs.get_md5(file)
   end
   local ok, err = fs.change_dir(temp_dir)
   if not ok then return false end
   fs.unpack_archive(file)
   local base_dir = fetch.url_to_base_dir(url)
   if not fs.exists(base_dir) then
      util.printerr("Directory "..base_dir.." not found")
      local files = fs.list_dir()
      if files[1] and fs.is_dir(files[1]) then
         util.printerr("Found "..files[1])
         base_dir = files[1]
      end
   end
   fs.pop_dir()
   return true, base_dir, temp_dir
end

local function configure_lua_version(rockspec, luaver)
   if luaver == "5.1" then
      table.insert(rockspec.dependencies, "lua ~> 5.1")
   elseif luaver == "5.2" then
      table.insert(rockspec.dependencies, "lua ~> 5.2")
   elseif luaver == "5.1,5.2" then
      table.insert(rockspec.dependencies, "lua >= 5.1, < 5.3")
   else
      util.warning("Please specify supported Lua version with --lua-version=<ver>. "..util.see_help("write_rockspec"))
   end
end

local function detect_description(rockspec)
   local fd = io.open("README.md", "r")
   if not fd then fd = io.open("README", "r") end
   if not fd then return end
   local data = fd:read("*a")
   fd:close()
   local paragraph = data:match("\n\n(.-)\n\n")
   if not paragraph then paragraph = data:match("\n\n(.*)") end
   if paragraph then
      if #paragraph < 80 then
         rockspec.description.summary = paragraph:gsub("\n", "")
         rockspec.description.detailed = paragraph
      else
         local summary = paragraph:gsub("\n", " "):match("([^.]*%.) ")
         if summary then
            rockspec.description.summary = summary:gsub("\n", "")
         end
         rockspec.description.detailed = paragraph
      end
   end
end

local function show_license(rockspec)
   local fd = io.open("COPYING", "r")
   if not fd then fd = io.open("LICENSE", "r") end
   if not fd then return end
   local data = fd:read("*a")
   fd:close()
   util.title("License for "..rockspec.package..":")
   util.printout(data)
   util.printout()
end

local function get_cmod_name(file)
   local fd = io.open(file, "r")
   if not fd then return nil end
   local data = fd:read("*a")
   fd:close()
   return (data:match("int%s+luaopen_([a-zA-Z0-9_]+)"))
end

local luamod_blacklist = {
   test = true,
   tests = true,
}

local function fill_as_builtin(rockspec, libs)
   rockspec.build.type = "builtin"
   rockspec.build.modules = {}
   local prefix = ""

   for _, parent in ipairs({"src", "lua"}) do
      if fs.is_dir(parent) then
         fs.change_dir(parent)
         prefix = parent.."/"
         break
      end
   end
   
   local incdirs, libdirs
   if libs then
      incdirs, libdirs = {}, {}
      for _, lib in ipairs(libs) do
         local upper = lib:upper()
         incdirs[#incdirs+1] = "$("..upper.."_INCDIR)"
         libdirs[#libdirs+1] = "$("..upper.."_LIBDIR)"
      end
   end

   for _, file in ipairs(fs.find()) do
      local luamod = file:match("(.*)%.lua$")
      if luamod and not luamod_blacklist[luamod] then
         rockspec.build.modules[path.path_to_module(file)] = prefix..file
      else
         local cmod = file:match("(.*)%.c$")
         if cmod then
            local modname = get_cmod_name(file) or path.path_to_module(file:gsub("%.c$", ".lua"))
            rockspec.build.modules[modname] = {
               sources = prefix..file,
               libraries = libs,
               incdirs = incdirs,
               libdirs = libdirs,
            }
         end
      end
   end
   
   for _, directory in ipairs({ "doc", "docs", "samples", "tests" }) do
      if fs.is_dir(directory) then
         if not rockspec.build.copy_directories then
            rockspec.build.copy_directories = {}
         end
         table.insert(rockspec.build.copy_directories, directory)
      end
   end
   
   if prefix ~= "" then
      fs.pop_dir()
   end
end

local function rockspec_cleanup(rockspec)
   rockspec.source.file = nil
   rockspec.source.protocol = nil
   rockspec.variables = nil
   rockspec.name = nil
end

function run(...)
   local flags, name, version, url_or_dir = util.parse_flags(...)
   
   if not name then
      return nil, "Missing arguments. "..util.see_help("write_rockspec")
   end

   if name and not version then
      url_or_dir = name
      name = nil
   elseif not url_or_dir then
      url_or_dir = version
   end
   
   local protocol, pathname = dir.split_url(url_or_dir)
   if not fetch.is_basic_protocol(protocol) then
      version = "scm"
      if not name then
         name = dir.base_name(url_or_dir):gsub("%.[^.]+$", "")
      end
   elseif protocol ~= "file" then
      local filename = dir.base_name(url_or_dir)
      local newname, newversion = filename:match("(.*)-([^-]+)")
      if not name then
         name = newname
      end
      if newversion then
         version = newversion:gsub(".[a-z]+$", ""):gsub(".tar$", "")
      else
         return nil, "Missing name and version arguments. "..util.see_help("write_rockspec")
      end
   elseif not version then
      return nil, "Missing name and version arguments. "..util.see_help("write_rockspec")
   end

   local filename = flags["output"] or dir.path(fs.current_dir(), name:lower().."-"..version.."-1.rockspec")

   local rockspec = {
      package = name,
      name = name:lower(),
      version = version.."-1",
      source = {
         url = "*** please add URL for source tarball, zip or repository here ***"
      },
      description = {
         summary = flags["summary"] or "*** please specify description summary ***",
         detailed = flags["detailed"] or "*** please enter a detailed description ***",
         homepage = flags["homepage"] or "*** please enter a project homepage ***",
         license = flags["license"] or "*** please specify a license ***",
      },
      dependencies = {},
      build = {},
   }
   path.configure_paths(rockspec)
   rockspec.source.protocol = protocol
   
   configure_lua_version(rockspec, flags["lua-version"])
   
   local local_dir = url_or_dir

   if url_or_dir:match("://") then
      rockspec.source.url = url_or_dir
      rockspec.source.file = dir.base_name(url_or_dir)
      rockspec.source.dir = "dummy"
      if not fetch.is_basic_protocol(rockspec.source.protocol) then
         if version ~= "scm" then
            rockspec.source.tag = "v" .. version
         end
      end
      rockspec.source.dir = nil
      local ok, base_dir, temp_dir = get_url(rockspec)
      if ok then
         if base_dir ~= dir.base_name(url_or_dir) then
            rockspec.source.dir = base_dir
         end
      end
      if base_dir then
         local_dir = dir.path(temp_dir, base_dir)
      else
         local_dir = nil
      end
   end
   
   if not local_dir then
      local_dir = "."
   end
   
   local libs = nil
   if flags["lib"] then
      libs = {}
      rockspec.external_dependencies = {}
      for lib in flags["lib"]:gmatch("([^,]+)") do
         table.insert(libs, lib)
         rockspec.external_dependencies[lib:upper()] = {
            library = lib
         }
      end
   end

   local ok, err = fs.change_dir(local_dir)
   if not ok then return nil, "Failed reaching files from project - error entering directory "..local_dir end

   detect_description(rockspec)

   show_license(rockspec)
   
   fill_as_builtin(rockspec, libs)
      
   rockspec_cleanup(rockspec)
   
   persist.save_from_table(filename, rockspec, type_check.rockspec_order)

   util.printout()   
   util.printout("Wrote template at "..filename.." -- you should now edit and finish it.")
   util.printout()   

   return true
end
