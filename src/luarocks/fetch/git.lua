
--- Fetch back-end for retrieving sources from GIT.
module("luarocks.fetch.git", package.seeall)

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")

--- Download sources for building a rock, using git.
-- @param rockspec table: The rockspec table
-- @param extract boolean: Unused in this module (required for API purposes.)
-- @param dest_dir string or nil: If set, will extract to the given directory.
-- @return (string, string) or (nil, string): The absolute pathname of
-- the fetched source tarball and the temporary directory created to
-- store it; or nil and an error message.
function get_sources(rockspec, extract, dest_dir)
   assert(type(rockspec) == "table")
   assert(type(dest_dir) == "string" or not dest_dir)

   local git_cmd = rockspec.variables.GIT
   local name_version = rockspec.name .. "-" .. rockspec.version
   local module = dir.base_name(rockspec.source.url)
   -- Strip off .git from base name if present
   module = module:gsub("%.git$", "")
   local command = {git_cmd, "clone", "--depth=1", rockspec.source.url, module}
   local checkout_command
   local tag_or_branch = rockspec.source.tag or rockspec.source.branch
   if tag_or_branch then
      checkout_command = {git_cmd, "checkout", "-q", tag_or_branch}
   end
   local store_dir
   if not dest_dir then
      store_dir = fs.make_temp_dir(name_version)
      if not store_dir then
         return nil, "Failed creating temporary directory."
      end
      util.schedule_function(fs.delete, store_dir)
   else
      store_dir = dest_dir
   end
   store_dir = fs.absolute_name(store_dir)
   fs.change_dir(store_dir)
   if not fs.execute(unpack(command)) then
      return nil, "Failed cloning git repository."
   end
   fs.change_dir(module)
   if checkout_command then
      if not fs.execute(unpack(checkout_command)) then
         return nil, "Failed checking out tag/branch from git repository."
      end
   end
   fs.delete(dir.path(store_dir, module, ".git"))
   fs.delete(dir.path(store_dir, module, ".gitignore"))
   fs.pop_dir()
   fs.pop_dir()
   return module, store_dir
end

