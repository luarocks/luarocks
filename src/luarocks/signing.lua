local signing = {}

local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")

function signing.sign_file(file)
   local vars = cfg.variables
   local gpg_ok, err = fs.is_tool_available(vars.GPG, "gpg")
   if not gpg_ok then
      return nil, err
   end
   local gpg = vars.GPG
   
   local sigfile = file .. ".asc"
   if fs.execute(gpg, "--armor", "--output", sigfile, "--detach-sign", file) then
      return sigfile
   else
      return nil, "failed running " .. gpg .. " to sign " .. file
   end
end

return signing
