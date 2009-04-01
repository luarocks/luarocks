
--- Module implementing the LuaRocks "pack" command.
-- Creates a rock, packing sources or binaries.
module("luarocks.pack", package.seeall)

local path = require("luarocks.path")
local rep = require("luarocks.rep")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")

help_summary = "Create a rock, packing sources or binaries."
help_arguments = "{<rockspec>|<name> [<version>]}"
help = [[
Argument may be a rockspec file, for creating a source rock,
or the name of an installed package, for creating a binary rock.
In the latter case, the app version may be given as a second
argument.
]]

--- Create a source rock.
-- Packages a rockspec and its required source files in a rock
-- file with the .src.rock extension, which can later be built and
-- installed with the "build" command.
-- @param rockspec_file string: An URL or pathname for a rockspec file.
-- @return string or (nil, string): The filename of the resulting
-- .src.rock file; or nil and an error message.
local function pack_source_rock(rockspec_file)
   assert(type(rockspec_file) == "string")

   rockspec_file = fs.absolute_name(rockspec_file)
   local rockspec, err = fetch.load_rockspec(rockspec_file)
   if err then
      return nil, "Error loading rockspec: "..err
   end

   local name_version = rockspec.name .. "-" .. rockspec.version
   local rock_file = fs.absolute_name(name_version .. ".src.rock")

   local source_file, dir = fetch.fetch_sources(rockspec, false)
   if not source_file then
      return nil, dir
   end
   fs.change_dir(dir)

   fs.delete(rock_file)
   fs.copy(rockspec_file, dir)
   if not fs.zip(rock_file, fs.base_name(rockspec_file), fs.base_name(source_file)) then
      return nil, "Failed packing "..rock_file
   end
   fs.pop_dir()

   return rock_file
end

-- @param name string: Name of package to pack.
-- @param version string or nil: A version number may also be passed.
-- @return string or (nil, string): The filename of the resulting
-- .src.rock file; or nil and an error message.
local function pack_binary_rock(name, version)
   assert(type(name) == "string")
   assert(type(version) == "string" or not version)
   
   local versions = rep.get_versions(name)
   
   if not versions then
      return nil, "'"..name.."' does not seem to be an installed rock."
   end
   if not version then
      if #versions > 1 then
         return nil, "Please specify which version of '"..name.."' to pack."
      end
      version = versions[1]
   end
   if not version:match("[^-]+%-%d+") then
      return nil, "Expected version "..version.." in version-revision format."
   end
   local prefix = path.install_dir(name, version)
   if not fs.exists(prefix) then
      return nil, "'"..name.." "..version.."' does not seem to be an installed rock."
   end
   local name_version = name .. "-" .. version
   local rock_file = fs.absolute_name(name_version .. "."..cfg.arch..".rock")
   fs.change_dir(prefix)
   if not rep.is_binary_rock(name, version) then
      rock_file = rock_file:gsub("%."..cfg.arch:gsub("%-","%%-").."%.", ".all.")
   end
   fs.delete(rock_file)
   if not fs.zip(rock_file, unpack(fs.dir())) then
      return nil, "Failed packing "..rock_file
   end
   fs.pop_dir()
   return rock_file
end

--- Driver function for the "pack" command.
-- @param arg string:  may be a rockspec file, for creating a source rock,
-- or the name of an installed package, for creating a binary rock.
-- @param version string or nil: if the name of a package is given, a
-- version may also be passed.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
function run(...)
   local flags, arg, version = util.parse_flags(...)
   assert(type(version) == "string" or not version)
   if type(arg) ~= "string" then
      return nil, "Argument missing, see help."
   end

   if arg:match(".*%.rockspec") then
      return pack_source_rock(arg)
   else
      return pack_binary_rock(arg, version)
   end
end
