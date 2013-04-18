
--- Module implementing the LuaRocks "lint" command.
-- Utility function that checks syntax of the rockspec.
module("luarocks.lint", package.seeall)

local util = require("luarocks.util")
local download = require("luarocks.download")
local fetch = require("luarocks.fetch")

help_summary = "Check syntax of a rockspec."
help_arguments = "<rockspec>"
help = [[
This is a utility function that checks the syntax of a rockspec.

It returns success or failure if the text of a rockspec is
syntactically correct.
]]

function run(...)
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

   return true
end
