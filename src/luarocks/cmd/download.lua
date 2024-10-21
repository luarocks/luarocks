


local cmd_download = {}


local util = require("luarocks.util")
local download = require("luarocks.download")





function cmd_download.add_to_parser(parser)
   local cmd = parser:command("download", "Download a specific rock file from a rocks server.", util.see_also())

   cmd:argument("name", "Name of the rock."):
   args("?"):
   action(util.namespaced_name_action)
   cmd:argument("version", "Version of the rock."):
   args("?")

   cmd:flag("--all", "Download all files if there are multiple matches.")
   cmd:mutex(
   cmd:flag("--source", "Download .src.rock if available."),
   cmd:flag("--rockspec", "Download .rockspec if available."),
   cmd:option("--arch", "Download rock for a specific architecture."))
   cmd:flag("--check-lua-versions", "If the rock can't be found, check repository " ..
   "and report if it is available for another Lua version.")
end




function cmd_download.command(args)
   if not args.name and not args.all then
      return nil, "Argument missing. " .. util.see_help("download")
   end

   args.name = args.name or ""

   local arch

   if args.source then
      arch = "src"
   elseif args.rockspec then
      arch = "rockspec"
   elseif args.arch then
      arch = args.arch
   end

   if args.all then
      local ok, err = download.download_all(arch, args.name, args.namespace, args.version)
      return ok, err
   else
      local dl, err = download.download_file(arch, args.name, args.namespace, args.version, args.check_lua_versions)
      return dl and true, err
   end
end

return cmd_download
