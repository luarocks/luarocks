
local write_rockspec = {}

local builtin = require("luarocks.build.builtin")
local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local persist = require("luarocks.persist")
local rockspecs = require("luarocks.rockspecs")
local type_rockspec = require("luarocks.type.rockspec")
local util = require("luarocks.util")

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
using 'dev' as a fallback default version.

Note that the generated file is a _starting point_ for writing a
rockspec, and is not guaranteed to be complete or correct.

--output=<file>          Write the rockspec with the given filename.
                         If not given, a file is written in the current
                         directory with a filename based on given name and version.
--license="<string>"     A license string, such as "MIT/X11" or "GNU GPL v3".
--summary="<txt>"        A short one-line description summary.
--detailed="<txt>"       A longer description string.
--homepage=<url>         Project homepage.
--lua-versions=<ver>     Supported Lua versions.  Accepted values are: "5.1", "5.2",
                         "5.3", "5.4", "5.1,5.2", "5.2,5.3", "5.3,5.4", "5.1,5.2,5.3",
                         "5.2,5.3,5.4", or "5.1,5.2,5.3,5.4"
--rockspec-format=<ver>  Rockspec format version, such as "1.0" or "1.1".
--tag=<tag>              Tag to use. Will attempt to extract version number from it.
--lib=<lib>[,<lib>]      A comma-separated list of libraries that C files need to
                         link to.
]]

local function open_file(name)
   return io.open(dir.path(fs.current_dir(), name), "r")
end

local function fetch_url(rockspec)
   local file, temp_dir, err_code, err_file, err_temp_dir = fetch.fetch_sources(rockspec, false)
   if err_code == "source.dir" then
      file, temp_dir = err_file, err_temp_dir
   elseif not file then
      util.warning("Could not fetch sources - "..temp_dir)
      return false
   end
   util.printout("File successfully downloaded. Making checksum and checking base dir...")
   if dir.is_basic_protocol(rockspec.source.protocol) then
      rockspec.source.md5 = fs.get_md5(file)
   end
   local inferred_dir, found_dir = fetch.find_base_dir(file, temp_dir, rockspec.source.url)
   return true, found_dir or inferred_dir, temp_dir
end

local lua_version_dep = {
   ["5.1"] = "lua ~> 5.1",
   ["5.2"] = "lua ~> 5.2",
   ["5.3"] = "lua ~> 5.3",
   ["5.4"] = "lua ~> 5.4",
   ["5.1,5.2"] = "lua >= 5.1, < 5.3",
   ["5.2,5.3"] = "lua >= 5.2, < 5.4",
   ["5.3,5.4"] = "lua >= 5.3, < 5.5",
   ["5.1,5.2,5.3"] = "lua >= 5.1, < 5.4",
   ["5.2,5.3,5.4"] = "lua >= 5.2, < 5.5",
   ["5.1,5.2,5.3,5.4"] = "lua >= 5.1, < 5.5",
}

local simple_scm_protocols = {
   git = true,
   ["git+http"] = true,
   ["git+https"] = true,
   ["git+ssh"] = true,
   hg = true,
   ["hg+http"] = true,
   ["hg+https"] = true,
   ["hg+ssh"] = true,
}

local detect_url
do
   local function detect_url_from_command(program, args, directory)
      local command = fs.Q(cfg.variables[program:upper()]).. " "..args
      local pipe = io.popen(fs.command_at(directory, fs.quiet_stderr(command)))
      if not pipe then return nil end
      local url = pipe:read("*a"):match("^([^\r\n]+)")
      pipe:close()
      if not url then return nil end
      if url:match("^[^@:/]+@[^@:/]+:.*$") then
         local u, h, p = url:match("^([^@]+)@([^:]+):(.*)$")
         url = program.."+ssh://"..u.."@"..h.."/"..p
      elseif not util.starts_with(url, program.."://") then
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

   detect_url = function(url_or_dir)
      if url_or_dir:match("://") then
         return url_or_dir
      else
         return detect_scm_url(url_or_dir) or "*** please add URL for source tarball, zip or repository here ***"
      end
   end
end

local function detect_homepage(url, homepage)
   if homepage then
      return homepage
   end
   local url_protocol, url_path = dir.split_url(url)

   if simple_scm_protocols[url_protocol] then
      for _, domain in ipairs({"github.com", "bitbucket.org", "gitlab.com"}) do
         if util.starts_with(url_path, domain) then
            return "https://"..url_path:gsub("%.git$", "")
         end
      end
   end

   return "*** please enter a project homepage ***"
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

local licenses = {
   [78656] = "MIT",
   [49311] = "ISC",
}

local function detect_license(data)
   local strip_copyright = (data:gsub("^Copyright [^\n]*\n", ""))
   local sum = 0
   for i = 1, #strip_copyright do
      local num = string.byte(strip_copyright:sub(i,i))
      if num > 32 and num <= 128 then
         sum = sum + num
      end
   end
   return licenses[sum]
end

local function check_license()
   local fd = open_file("COPYING") or open_file("LICENSE") or open_file("MIT-LICENSE.txt")
   if not fd then return nil end
   local data = fd:read("*a")
   fd:close()
   local license = detect_license(data)
   if license then
      return license, data
   end
   return nil, data
end

local function fill_as_builtin(rockspec, libs)
   rockspec.build.type = "builtin"

   local incdirs, libdirs
   if libs then
      incdirs, libdirs = {}, {}
      for _, lib in ipairs(libs) do
         local upper = lib:upper()
         incdirs[#incdirs+1] = "$("..upper.."_INCDIR)"
         libdirs[#libdirs+1] = "$("..upper.."_LIBDIR)"
      end
   end
   
   rockspec.build.modules, rockspec.build.install, rockspec.build.copy_directories = builtin.autodetect_modules(libs, incdirs, libdirs)
end

local function rockspec_cleanup(rockspec)
   rockspec.source.file = nil
   rockspec.source.protocol = nil
   rockspec.source.identifier = nil
   rockspec.source.dir = nil
   rockspec.source.dir_set = nil
   rockspec.source.pathname = nil
   rockspec.variables = nil
   rockspec.name = nil
   rockspec.format_is_at_least = nil
   rockspec.local_abs_filename = nil
   rockspec.rocks_provided = nil
   for _, list in ipairs({"dependencies", "build_dependencies", "test_dependencies"}) do
      if rockspec[list] and not next(rockspec[list]) then
         rockspec[list] = nil
      end
   end
   for _, list in ipairs({"dependencies", "build_dependencies", "test_dependencies"}) do
      if rockspec[list] then
         for i, entry in ipairs(rockspec[list]) do
            rockspec[list][i] = tostring(entry)
         end
      end
   end
end

function write_rockspec.command(flags, name, version, url_or_dir)

   name = util.adjust_name_and_namespace(name, flags)

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
   elseif dir.is_basic_protocol(protocol) then
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
   version = version or "dev"

   local filename = flags["output"] or dir.path(fs.current_dir(), name:lower().."-"..version.."-1.rockspec")
   
   local url = detect_url(url_or_dir)
   local homepage = detect_homepage(url, flags["homepage"])
   
   local rockspec, err = rockspecs.from_persisted_table(filename, {
      rockspec_format = flags["rockspec-format"],
      package = name,
      version = version.."-1",
      source = {
         url = url,
         tag = flags["tag"],
      },
      description = {
         summary = flags["summary"] or "*** please specify description summary ***",
         detailed = flags["detailed"] or "*** please enter a detailed description ***",
         homepage = homepage,
         license = flags["license"] or "*** please specify a license ***",
      },
      dependencies = {
         lua_version_dep[flags["lua-versions"]],
      },
      build = {},
   })
   assert(not err, err)
   rockspec.source.protocol = protocol
   
   if not next(rockspec.dependencies) then
      util.warning("Please specify supported Lua versions with --lua-versions=<ver>. "..util.see_help("write_rockspec"))
   end
   
   local local_dir = url_or_dir

   if url_or_dir:match("://") then
      rockspec.source.file = dir.base_name(url_or_dir)
      if not dir.is_basic_protocol(rockspec.source.protocol) then
         if version ~= "dev" then
            rockspec.source.tag = flags["tag"] or "v" .. version
         end
      end
      rockspec.source.dir = nil
      local ok, base_dir, temp_dir = fetch_url(rockspec)
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

   if not (flags["summary"] and flags["detailed"]) then
      local summary, detailed = detect_description()
      rockspec.description.summary = flags["summary"] or summary
      rockspec.description.detailed = flags["detailed"] or detailed
   end

   if not flags["license"] then
      local license, fulltext = check_license()
      if license then
         rockspec.description.license = license
      elseif license then
         util.title("Could not auto-detect type for project license:")
         util.printout(fulltext)
         util.printout()
         util.title("Please fill in the source.license field manually or use --license.")
      end
   end
   
   fill_as_builtin(rockspec, libs)
      
   rockspec_cleanup(rockspec)
   
   persist.save_from_table(filename, rockspec, type_rockspec.order)

   util.printout()   
   util.printout("Wrote template at "..filename.." -- you should now edit and finish it.")
   util.printout()   

   return true
end

return write_rockspec
