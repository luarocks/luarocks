
--- Fetch back-end for retrieving sources from GIT.
local git = {}

local unpack = unpack or table.unpack

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")

--- Git >= 1.7.10 can clone a branch **or tag**, < 1.7.10 by branch only. We
-- need to know this in order to build the appropriate command; if we can't
-- clone by tag then we'll have to issue a subsequent command to check out the
-- given tag.
-- @return boolean: Whether Git can clone by tag.
local function git_can_clone_by_tag(git_cmd)
   local version_string = io.popen(fs.Q(git_cmd)..' --version'):read()
   local major, minor, tiny = version_string:match('(%d-)%.(%d+)%.?(%d*)')
   major, minor, tiny = tonumber(major), tonumber(minor), tonumber(tiny) or 0
   local value = major > 1 or (major == 1 and (minor > 7 or (minor == 7 and tiny >= 10)))
   git_can_clone_by_tag = function() return value end
   return value
end

--- Download sources for building a rock, using git.
-- @param rockspec table: The rockspec table
-- @param extract boolean: Unused in this module (required for API purposes.)
-- @param dest_dir string or nil: If set, will extract to the given directory.
-- @return (string, string) or (nil, string): The absolute pathname of
-- the fetched source tarball and the temporary directory created to
-- store it; or nil and an error message.
function git.get_sources(rockspec, extract, dest_dir, depth)
   assert(type(rockspec) == "table")
   assert(type(dest_dir) == "string" or not dest_dir)

   local git_cmd = rockspec.variables.GIT
   local name_version = rockspec.name .. "-" .. rockspec.version
   local module = dir.base_name(rockspec.source.url)
   -- Strip off .git from base name if present
   module = module:gsub("%.git$", "")

   local ok, err_msg = fs.is_tool_available(git_cmd, "Git")
   if not ok then
      return nil, err_msg
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
   local ok, err = fs.change_dir(store_dir)
   if not ok then return nil, err end

   local command = {fs.Q(git_cmd), "clone", depth or "--depth=1", rockspec.source.url, module}
   local tag_or_branch = rockspec.source.tag or rockspec.source.branch
   -- If the tag or branch is explicitly set to "master" in the rockspec, then
   -- we can avoid passing it to Git since it's the default.
   if tag_or_branch == "master" then tag_or_branch = nil end
   if tag_or_branch then
      if git_can_clone_by_tag(git_cmd) then
         -- The argument to `--branch` can actually be a branch or a tag as of
         -- Git 1.7.10.
         table.insert(command, 3, "--branch=" .. tag_or_branch)
      end
   end
   if not fs.execute(unpack(command)) then
      return nil, "Failed cloning git repository."
   end
   ok, err = fs.change_dir(module)
   if not ok then return nil, err end
   if tag_or_branch and not git_can_clone_by_tag() then
      local checkout_command = {fs.Q(git_cmd), "checkout", tag_or_branch}
      if not fs.execute(unpack(checkout_command)) then
         return nil, 'Failed to check out the "' .. tag_or_branch ..'" tag or branch.'
      end
   end

   fs.delete(dir.path(store_dir, module, ".git"))
   fs.delete(dir.path(store_dir, module, ".gitignore"))
   fs.pop_dir()
   fs.pop_dir()
   return module, store_dir
end

return git
