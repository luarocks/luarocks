






local hg_http = {}


local hg = require("luarocks.fetch.hg")










function hg_http.get_sources(rockspec, extract, dest_dir)
   rockspec.source.url = rockspec.source.url:gsub("^hg.", "")
   return hg.get_sources(rockspec, extract, dest_dir)
end

return hg_http
