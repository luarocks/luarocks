
--- Module implementing the LuaRocks "lint" command.
-- Utility function that checks syntax of the rockspec.
--module("luarocks.lint", package.seeall)
local lint = {}
package.loaded["luarocks.lint"] = lint

local util = require("luarocks.util")
local download = require("luarocks.download")
local fetch = require("luarocks.fetch")

lint.help_summary = "Check syntax of a rockspec."
lint.help_arguments = "<rockspec>"
lint.help = [[
This is a utility function that checks the syntax of a rockspec.

It returns success or failure if the text of a rockspec is
syntactically correct.
]]

function lint.run(...)
   local flags, input = util.parse_flags(...)
   
   if not input then
      return nil, "Argument missing. "..util.see_help("lint")
   end
   
   local filename = input
   if not input:match(".rockspec$") then
      local err
      filename, err = download.download("rockspec", input)
      if not filename then
         return nil, err
      end
   end

   local rs, err = fetch.load_local_rockspec(filename)
   if not rs then
      return nil, "Failed loading rockspec: "..err
   end

   local ok = true
   
   -- This should have been done in the type checker, 
   -- but it would break compatibility of other commands.
   -- Making 'lint' alone be stricter shouldn't be a problem,
   -- because extra-strict checks is what lint-type commands
   -- are all about.
   if not rs.description.license then
      util.printerr("Rockspec has no license field.")
      ok = false
   end

   return ok, ok or filename.." failed consistency checks."
end

return lint
