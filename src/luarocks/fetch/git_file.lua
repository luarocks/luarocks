local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string

local git_file = {}


local git = require("luarocks.fetch.git")










function git_file.get_sources(rockspec, extract, dest_dir)
   rockspec.source.url = rockspec.source.url:gsub("^git.file://", "")
   return git.get_sources(rockspec, extract, dest_dir)
end

return git_file
