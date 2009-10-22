
--- Module implementing the LuaRocks "make" command.
-- Builds sources in the current directory, but unlike "build",
-- it does not fetch sources, etc., assuming everything is 
-- available in the current directory.
module("luarocks.make", package.seeall)

local build = require("luarocks.build")
local fs = require("luarocks.fs")
local util = require("luarocks.util")

help_summary = "Compile package in current directory using a rockspec."
help_arguments = "[<rockspec>]"
help = [[
Builds sources in the current directory, but unlike "build",
it does not fetch sources, etc., assuming everything is 
available in the current directory. If no argument is given,
look for a rockspec in the current directory. If more than one
is found, you must specify which to use, through the command-line.

This command is useful as a tool for debugging rockspecs. 
To install rocks, you'll normally want to use the "install" and
"build" commands. See the help on those for details.
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

   return build.build_rockspec(rockspec, false, true)
end
