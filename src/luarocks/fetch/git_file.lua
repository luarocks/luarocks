

local git_file = {}


local git = require("luarocks.fetch.git")










function git_file.get_sources(rockspec, extract, dest_dir)
   rockspec.source.url = rockspec.source.url:gsub("^git.file://", "")
   return git.get_sources(rockspec, extract, dest_dir)
end

return git_file
