
--- Module implementing the luarocks-admin "make_manifest" command.
-- Compile a manifest file for a repository.
module("luarocks.make_manifest", package.seeall)

local manif = require("luarocks.manif")
local index = require("luarocks.index")
local cfg = require("luarocks.cfg")

help_summary = "Compile a manifest file for a repository."

help = [[
<argument>, if given, is a local repository pathname.
]]

--- Driver function for "make_manifest" command.
-- @param repo string or nil: Pathname of a local repository. If not given,
-- the default local repository configured as cfg.rocks_dir is used.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function run(repo)
   assert(type(repo) == "string" or not repo)
   repo = repo or cfg.rocks_dir
  
   print("Making manifest for "..repo)
   
   local ok, err = manif.make_manifest(repo)
   if ok then
      print("Generating index.html for "..repo)
      index.make_index(repo)
   end
   return ok, err
end
