local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string

local sscm = {}


local fs = require("luarocks.fs")
local dir = require("luarocks.dir")










function sscm.get_sources(rockspec, _extract, _dest_dir)

   local sscm_cmd = rockspec.variables.SSCM
   local module = rockspec.source.module or dir.base_name(rockspec.source.url)
   local branch, repository = string.match(rockspec.source.pathname, "^([^/]*)/(.*)")
   if not branch or not repository then
      return nil, "Error retrieving branch and repository from rockspec."
   end

   local working_dir
   local tmp = io.popen(string.format(sscm_cmd .. [[ property "/" -d -b%s -p%s]], branch, repository))
   for line in tmp:lines() do

      working_dir = string.match(line, "Working directory:[%s]*(.*)%c$")
      if working_dir then break end
   end
   tmp:close()
   if not working_dir then
      return nil, "Error retrieving working directory from SSCM."
   end
   if not fs.execute(sscm_cmd, "get", "*", "-e", "-r", "-b" .. branch, "-p" .. repository, "-tmodify", "-wreplace") then
      return nil, "Failed fetching files from SSCM."
   end

   return module, working_dir
end

return sscm
