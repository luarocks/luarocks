








local git_ssh = {}


local git = require("luarocks.fetch.git")
local cfg = require("luarocks.core.cfg")










function git_ssh.get_sources(rockspec, extract, dest_dir)
   rockspec.source.url = rockspec.source.url:gsub("^git.", "")


   if rockspec.source.url:match("^ssh://[^/]+:[^%d]") then
      rockspec.source.url = rockspec.source.url:gsub("^ssh://", "")
   end

   return git.get_sources(rockspec, extract, dest_dir, "--")
end

return git_ssh
