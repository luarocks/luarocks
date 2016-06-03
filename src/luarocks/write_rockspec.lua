
local write_rockspec = {}
package.loaded["luarocks.write_rockspec"] = write_rockspec

local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local persist = require("luarocks.persist")
local type_check = require("luarocks.type_check")
local util = require("luarocks.util")

util.add_run_function(write_rockspec)
write_rockspec.help_summary = "Write a template for a rockspec file."
write_rockspec.help_arguments = "[--output=<file> ...] [<name>] [<version>] [<url>|<path>]"
write_rockspec.help = [[
This command writes an initial version of a rockspec file,
based on a name, a version, and a location (an URL or a local path).
If only two arguments are given, the first one is considered the name and the
second one is the location.
If only one argument is given, it must be the location.
If no arguments are given, current directory is used as location.
LuaRocks will attempt to infer name and version if not given,
using 'scm' as default version.

Note that the generated file is a _starting point_ for writing a
rockspec, and is not guaranteed to be complete or correct.

--output=<file>          Write the rockspec with the given filename.
                         If not given, a file is written in the current
                         directory with a filename based on given name and version.
--license="<string>"     A license string, such as "MIT/X11" or "GNU GPL v3".
--summary="<txt>"        A short one-line description summary.
--detailed="<txt>"       A longer description string.
--homepage=<url>         Project homepage.
--lua-version=<ver>      Supported Lua versions. Accepted values are "5.1", "5.2",
                         "5.3", "5.1,5.2", "5.2,5.3", or "5.1,5.2,5.3".
--rockspec-format=<ver>  Rockspec format version, such as "1.0" or "1.1".
--tag=<tag>              Tag to use. Will attempt to extract version number from it.
--lib=<lib>[,<lib>]      A comma-separated list of libraries that C files need to
                         link to.
]]

local function open_file(name)
   return io.open(dir.path(fs.current_dir(), name), "r")
end

local function get_url(rockspec)
   local file, temp_dir, err_code, err_file, err_temp_dir = fetch.fetch_sources(rockspec, false)
   if err_code == "source.dir" then
      file, temp_dir = err_file, err_temp_dir
   elseif not file then
      util.warning("Could not fetch sources - "..temp_dir)
      return false
   end
   util.printout("File successfully downloaded. Making checksum and checking base dir...")
   if fetch.is_basic_protocol(rockspec.source.protocol) then
      rockspec.source.md5 = fs.get_md5(file)
   end
   local inferred_dir, found_dir = fetch.find_base_dir(file, temp_dir, rockspec.source.url)
   return true, found_dir or inferred_dir, temp_dir
end

local function configure_lua_version(rockspec, luaver)
   if luaver == "5.1" then
      table.insert(rockspec.dependencies, "lua ~> 5.1")
   elseif luaver == "5.2" then
      table.insert(rockspec.dependencies, "lua ~> 5.2")
   elseif luaver == "5.3" then
      table.insert(rockspec.dependencies, "lua ~> 5.3")
   elseif luaver == "5.1,5.2" then
      table.insert(rockspec.dependencies, "lua >= 5.1, < 5.3")
   elseif luaver == "5.2,5.3" then
      table.insert(rockspec.dependencies, "lua >= 5.2, < 5.4")
   elseif luaver == "5.1,5.2,5.3" then
      table.insert(rockspec.dependencies, "lua >= 5.1, < 5.4")
   else
      util.warning("Please specify supported Lua version with --lua-version=<ver>. "..util.see_help("write_rockspec"))
   end
end

local function detect_description()
   local fd = open_file("README.md") or open_file("README")
   if not fd then return end
   local data = fd:read("*a")
   fd:close()
   local paragraph = data:match("\n\n([^%[].-)\n\n")
   if not paragraph then paragraph = data:match("\n\n(.*)") end
   local summary, detailed
   if paragraph then
      detailed = paragraph

      if #paragraph < 80 then
         summary = paragraph:gsub("\n", "")
      else
         summary = paragraph:gsub("\n", " "):match("([^.]*%.) ")
      end
   end
   return summary, detailed
end

local function detect_mit_license(data)
   local strip_copyright = (data:gsub("Copyright [^\n]*\n", ""))
   local sum = 0
   for i = 1, #strip_copyright do
      local num = string.byte(strip_copyright:sub(i,i))
      if num > 32 and num <= 128 then
         sum = sum + num
      end
   end
   return sum == 78656
end

local simple_scm_protocols = {
   git = true, ["git+http"] = true, ["git+https"] = true,
   hg = true, ["hg+http"] = true, ["hg+https"] = true
}

local function detect_url_from_command(program, args, directory)
   local command = fs.Q(cfg.variables[program:upper()]).. " "..args
   local pipe = io.popen(fs.command_at(directory, fs.quiet_stderr(command)))
   if not pipe then return nil end
   local url = pipe:read("*a"):match("^([^\r\n]+)")
   pipe:close()
   if not url then return nil end
   if not util.starts_with(url, program.."://") then
      url = program.."+"..url
   end

   if simple_scm_protocols[dir.split_url(url)] then
      return url
   end
end

local function detect_scm_url(directory)
   return detect_url_from_command("git", "config --get remote.origin.url", directory) or
      detect_url_from_command("hg", "paths default", directory)
end

local function show_license(rockspec)
   local fd = open_file("COPYING") or open_file("LICENSE") or open_file("MIT-LICENSE.txt")
   if not fd then return nil end
   local data = fd:read("*a")
   fd:close()
   local is_mit = detect_mit_license(data)
   util.title("License for "..rockspec.package..":")
   util.printout(data)
   util.printout()
   return is_mit
end

local function get_cmod_name(file)
   local fd = open_file(file)
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

function write_rockspec.command(flags, name, version, url_or_dir)
   if not name then
      url_or_dir = "."
   elseif not version then
      url_or_dir = name
      name = nil
   elseif not url_or_dir then
      url_or_dir = version
      version = nil
   end

   if flags["tag"] then
      if not version then
         version = flags["tag"]:gsub("^v", "")
      end
   end

   local protocol, pathname = dir.split_url(url_or_dir)
   if protocol == "file" then
      if pathname == "." then
         name = name or dir.base_name(fs.current_dir())
      end
   elseif fetch.is_basic_protocol(protocol) then
      local filename = dir.base_name(url_or_dir)
      local newname, newversion = filename:match("(.*)-([^-]+)")
      if newname then
         name = name or newname
         version = version or newversion:gsub("%.[a-z]+$", ""):gsub("%.tar$", "")
      end
   else
      name = name or dir.base_name(url_or_dir):gsub("%.[^.]+$", "")
   end

   if not name then
      return nil, "Could not infer rock name. "..util.see_help("write_rockspec")
   end
   version = version or "scm"

   local filename = flags["output"] or dir.path(fs.current_dir(), name:lower().."-"..version.."-1.rockspec")

   local rockspec = {
      rockspec_format = flags["rockspec-format"],
      package = name,
      name = name:lower(),
      version = version.."-1",
      source = {
         url = "*** please add URL for source tarball, zip or repository here ***",
         tag = flags["tag"],
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
            rockspec.source.tag = flags["tag"] or "v" .. version
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
   else
      rockspec.source.url = detect_scm_url(local_dir) or rockspec.source.url
   end
   
   if not local_dir then
      local_dir = "."
   end

   if not flags["homepage"] then
      local url_protocol, url_path = dir.split_url(rockspec.source.url)

      if simple_scm_protocols[url_protocol] then
         for _, domain in ipairs({"github.com", "bitbucket.org", "gitlab.com"}) do
            if util.starts_with(url_path, domain) then
               rockspec.description.homepage = "https://"..url_path:gsub("%.git$", "")
               break
            end
         end
      end
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

   if (not flags["summary"]) or (not flags["detailed"]) then
      local summary, detailed = detect_description()
      rockspec.description.summary = flags["summary"] or summary
      rockspec.description.detailed = flags["detailed"] or detailed
   end

   local is_mit = show_license(rockspec)
   
   if is_mit and not flags["license"] then
      rockspec.description.license = "MIT"
   end
   
   fill_as_builtin(rockspec, libs)
      
   rockspec_cleanup(rockspec)
   
   persist.save_from_table(filename, rockspec, type_check.rockspec_order)

   util.printout()   
   util.printout("Wrote template at "..filename.." -- you should now edit and finish it.")
   util.printout()   

   return true
end

return write_rockspec
