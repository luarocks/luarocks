local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string






local hg_http = {}


local hg = require("luarocks.fetch.hg")










function hg_http.get_sources(rockspec, extract, dest_dir)
   rockspec.source.url = rockspec.source.url:gsub("^hg.", "")
   return hg.get_sources(rockspec, extract, dest_dir)
end

return hg_http
