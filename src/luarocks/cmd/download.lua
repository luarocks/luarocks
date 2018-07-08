
--- Module implementing the luarocks "download" command.
-- Download a rock from the repository.
local cmd_download = {}

local util = require("luarocks.util")
local download = require("luarocks.download")

cmd_download.help_summary = "Download a specific rock file from a rocks server."
cmd_download.help_arguments = "[--all] [--arch=<arch> | --source | --rockspec] [<name> [<version>]]"
cmd_download.help = [[
--all          Download all files if there are multiple matches.
--source       Download .src.rock if available.
--rockspec     Download .rockspec if available.
--arch=<arch>  Download rock for a specific architecture.
]]

--- Driver function for the "download" command.
-- @param name string: a rock name.
-- @param version string or nil: if the name of a package is given, a
-- version may also be passed.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
function cmd_download.command(flags, name, version)
   assert(type(version) == "string" or not version)
   if type(name) ~= "string" and not flags["all"] then
      return nil, "Argument missing. "..util.see_help("download")
   end

   name = util.adjust_name_and_namespace(name, flags)

   if not name then name, version = "", "" end

   local arch

   if flags["source"] then
      arch = "src"
   elseif flags["rockspec"] then
      arch = "rockspec"
   elseif flags["arch"] then
      arch = flags["arch"]
   end
   
   local dl, err = download.download(arch, name:lower(), version, flags["all"])
   return dl and true, err
end

return cmd_download
