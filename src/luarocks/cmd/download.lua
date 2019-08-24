
--- Module implementing the luarocks "download" command.
-- Download a rock from the repository.
local cmd_download = {}

local util = require("luarocks.util")
local download = require("luarocks.download")

function cmd_download.add_to_parser(parser)
   local cmd = parser:command("download", "Download a specific rock file from a rocks server.", util.see_also())

   cmd:argument("name", "Name of the rock.")
      :args("?")
   cmd:argument("version", "Version of the rock.")
      :args("?")

   cmd:flag("--all", "Download all files if there are multiple matches.")
   cmd:mutex(
      cmd:flag("--source", "Download .src.rock if available."),
      cmd:flag("--rockspec", "Download .rockspec if available."),
      cmd:option("--arch", "Download rock for a specific architecture."))
end

--- Driver function for the "download" command.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
function cmd_download.command(args)
   if not args.name and not args.all then
      return nil, "Argument missing. "..util.see_help("download")
   end

   local name = util.adjust_name_and_namespace(args.name, args)

   if not name then name, args.version = "", "" end

   local arch

   if args.source then
      arch = "src"
   elseif args.rockspec then
      arch = "rockspec"
   elseif args.arch then
      arch = args.arch
   end
   
   local dl, err = download.download(arch, name:lower(), args.version, args.all)
   return dl and true, err
end

return cmd_download
