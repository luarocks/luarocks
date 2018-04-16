
--- Module implementing the LuaRocks "test" command.
-- Tests a rock, compiling its C parts if any.
local cmd_test = {}

local util = require("luarocks.util")
local test = require("luarocks.test")

cmd_test.help_summary = "Run the test suite in the current directory."
cmd_test.help_arguments = "[<rockspec>] [-- <args>]"
cmd_test.help = [[
Run the test suite for the Lua project in the current directory.
If the first argument is a rockspec, it will use it to determine
the parameters for running tests; otherwise, it will attempt to
detect the rockspec.

Any additional arguments are forwarded to the test suite. 
To make sure that any flags passed in <args> are not interpreted
as LuaRocks flags, use -- to separate LuaRocks arguments from
test suite arguments.
]]..util.deps_mode_help()

--- Driver function for "build" command.
-- @param name string: A local or remote rockspec or rock file.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number may
-- also be given.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function cmd_test.command(flags, arg, ...)
   assert(type(arg) == "string" or not arg)

   local args = { ... }

   if arg and arg:match("rockspec$") then
      return test.run_test_suite(arg, args)
   end
   
   table.insert(args, 1, arg)
   
   local rockspec, err = util.get_default_rockspec()
   if not rockspec then
      return nil, err
   end

   return test.run_test_suite(rockspec, args)
end

return cmd_test
