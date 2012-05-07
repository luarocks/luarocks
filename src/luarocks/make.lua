
--- Module implementing the LuaRocks "make" command.
-- Builds sources in the current directory, but unlike "build",
-- it does not fetch sources, etc., assuming everything is 
-- available in the current directory.
module("luarocks.make", package.seeall)

local build = require("luarocks.build")
local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.cfg")
local fetch = require("luarocks.fetch")
local pack = require("luarocks.pack")

help_summary = "Compile package in current directory using a rockspec."
help_arguments = "[--pack-binary-rock] [<rockspec>]"
help = [[
Builds sources in the current directory, but unlike "build",
it does not fetch sources, etc., assuming everything is 
available in the current directory. If no argument is given,
look for a rockspec in the current directory. If more than one
is found, you must specify which to use, through the command-line.

This command is useful as a tool for debugging rockspecs. 
To install rocks, you'll normally want to use the "install" and
"build" commands. See the help on those for details.

If --pack-binary-rock is passed, the rock is not installed;
instead, a .rock file with the contents of compilation is produced
in the current directory.
]]

--- Driver function for "make" command.
-- @param name string: A local rockspec.
-- @return boolean or (nil, string): True if build was successful; nil and an
-- error message otherwise.
function run(...)
   local flags, rockspec = util.parse_flags(...)
   assert(type(rockspec) == "string" or not rockspec)
   
   if not rockspec then
      local files = fs.list_dir(fs.current_dir())
      for _, file in pairs(files) do
         if file:match("rockspec$") then
            if rockspec then
               return nil, "Please specify which rockspec file to use."
            else
               rockspec = file
            end
         end
      end
      if not rockspec then
         return nil, "Argument missing: please specify a rockspec to use on current directory."
      end
   end
   if not rockspec:match("rockspec$") then
      return nil, "Invalid argument: 'make' takes a rockspec as a parameter. See help."
   end

   if flags["pack-binary-rock"] then
      local rspec, err, errcode = fetch.load_rockspec(rockspec)
      if not rspec then
         return nil, err
      end
      return pack.pack_binary_rock(rspec.name, rspec.version, build.build_rockspec, rockspec, false, true, flags["nodeps"])
   else
      local ok, err = fs.check_command_permissions(flags)
      if not ok then return nil, err end
      return build.build_rockspec(rockspec, false, true)
   end
end
