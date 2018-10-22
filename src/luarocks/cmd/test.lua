
--- Module implementing the LuaRocks "test" command.
-- Tests a rock, compiling its C parts if any.
local cmd_test = {}

local util = require("luarocks.util")
local test = require("luarocks.test")

cmd_test.help_summary = "Run the test suite in the current directory."
cmd_test.help_arguments = "[--test-type=<type>] [<rockspec>] [-- <args>]"
cmd_test.help = [[
Run the test suite for the Lua project in the current directory.
If the first argument is a rockspec, it will use it to determine
the parameters for running tests; otherwise, it will attempt to
detect the rockspec.

Any additional arguments are forwarded to the test suite. 
To make sure that any flags passed in <args> are not interpreted
as LuaRocks flags, use -- to separate LuaRocks arguments from
test suite arguments.

--test-type=<type>  Specify the test suite type manually if it was not
                    specified in the rockspec and it could not be
                    auto-detected.

]]..util.deps_mode_help()

function cmd_test.command(flags, argument, ...)
   assert(type(argument) == "string" or not argument)

   local arguments = { ... }

   if argument and argument:match("rockspec$") then
      return test.run_test_suite(argument, flags["test-type"], arguments)
   end
   
   table.insert(arguments, 1, argument)
   
   local rockspec, err = util.get_default_rockspec()
   if not rockspec then
      return nil, err
   end

   return test.run_test_suite(rockspec, flags["test-type"], arguments)
end

return cmd_test
