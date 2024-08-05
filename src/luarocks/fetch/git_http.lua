








local git_http = {}


local git = require("luarocks.fetch.git")
local cfg = require("luarocks.core.cfg")










function git_http.get_sources(rockspec, extract, dest_dir)
   rockspec.source.url = rockspec.source.url:gsub("^git.", "")
   return git.get_sources(rockspec, extract, dest_dir, "--")
end

return git_http
