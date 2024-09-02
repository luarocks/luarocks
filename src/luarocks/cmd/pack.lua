local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string


local cmd_pack = {}


local util = require("luarocks.util")
local pack = require("luarocks.pack")
local queries = require("luarocks.queries")





function cmd_pack.add_to_parser(parser)
   local cmd = parser:command("pack", "Create a rock, packing sources or binaries.", util.see_also())

   cmd:argument("rock", "A rockspec file, for creating a source rock, or the " ..
   "name of an installed package, for creating a binary rock."):
   action(util.namespaced_name_action)
   cmd:argument("version", "A version may be given if the first argument is a rock name."):
   args("?")

   cmd:flag("--sign", "Produce a signature file as well.")
end




function cmd_pack.command(args)
   local file, err
   if args.rock:match(".*%.rockspec") then
      file, err = pack.pack_source_rock(args.rock)
   else
      local query = queries.new(args.rock, args.namespace, args.version)
      file, err = pack.pack_installed_rock(query, args.tree)
   end
   return pack.report_and_sign_local_file(file, err, args.sign)
end

return cmd_pack
