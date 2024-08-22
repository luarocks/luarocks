local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string


local lint = {}


local util = require("luarocks.util")
local download = require("luarocks.download")
local fetch = require("luarocks.fetch")





function lint.add_to_parser(parser)
   local cmd = parser:command("lint", "Check syntax of a rockspec.\n\n" ..
   "Returns success if the text of the rockspec is syntactically correct, else failure.",
   util.see_also()):
   summary("Check syntax of a rockspec.")

   cmd:argument("rockspec", "The rockspec to check.")
end

function lint.command(args)

   local filename = args.rockspec
   if not filename:match(".rockspec$") then
      local err
      filename, err = download.download_file("rockspec", filename:lower())
      if not filename then
         return nil, err
      end
   end

   local rs, err = fetch.load_local_rockspec(filename)
   if not rs then
      return nil, "Failed loading rockspec: " .. err
   end

   local ok = true






   if not rs.description or not rs.description.license then
      util.printerr("Rockspec has no description.license field.")
      ok = false
   end

   if ok then
      return ok
   end

   return nil, filename .. " failed consistency checks."
end

return lint
