--- Module implementing the LuaRocks "lint" command.
-- Utility function that checks syntax of the rockspec.
local lint = {}

local cmd = require("luarocks.cmd")
local luarocks = require("luarocks")

lint.help_summary = "Check syntax of a rockspec."
lint.help_arguments = "<rockspec>"
lint.help = [[
This is a utility function that checks the syntax of a rockspec.

It returns success or failure if the text of a rockspec is
syntactically correct.
]]

function lint.command(flags, input)
   if not input then
      return nil, "Argument missing. " .. cmd.see_help("lint")
   end

   return luarocks.lint(input, flags["tree"])
end

return lint
