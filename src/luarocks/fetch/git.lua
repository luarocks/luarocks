local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack

local git = {}



local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local vers = require("luarocks.core.vers")
local util = require("luarocks.util")




local cached_git_version




local function git_version(git_cmd)
   if not cached_git_version then
      local version_line = io.popen(fs.Q(git_cmd) .. ' --version'):read()
      local version_string = version_line:match('%d-%.%d+%.?%d*')
      cached_git_version = vers.parse_version(version_string)
   end

   return cached_git_version
end





local function git_is_at_least(git_cmd, version)
   return git_version(git_cmd) >= vers.parse_version(version)
end







local function git_can_clone_by_tag(git_cmd)
   return git_is_at_least(git_cmd, "1.7.10")
end





local function git_supports_shallow_submodules(git_cmd)
   return git_is_at_least(git_cmd, "1.8.4")
end




local function git_supports_shallow_recommendations(git_cmd)
   return git_is_at_least(git_cmd, "2.10.0")
end

local function git_identifier(git_cmd, ver)
   if not (ver:match("^dev%-%d+$") or ver:match("^scm%-%d+$")) then
      return nil
   end
   local pd = io.popen(fs.command_at(fs.current_dir(), fs.Q(git_cmd) .. " log --pretty=format:%ai_%h -n 1"))
   if not pd then
      return nil
   end
   local date_hash = pd:read("*l")
   pd:close()
   if not date_hash then
      return nil
   end
   local date, time, _tz, hash = date_hash:match("([^%s]+) ([^%s]+) ([^%s]+)_([^%s]+)")
   date = date:gsub("%-", "")
   time = time:gsub(":", "")
   return date .. "." .. time .. "." .. hash
end








function git.get_sources(rockspec, _extract, dest_dir, depth)

   local git_cmd = rockspec.variables.GIT
   local name_version = rockspec.name .. "-" .. rockspec.version
   local module = dir.base_name(rockspec.source.url)

   module = module:gsub("%.git$", "")

   local ok_available, err_msg = fs.is_tool_available(git_cmd, "Git")
   if not ok_available then
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

   local command = { fs.Q(git_cmd), "clone", depth or "--depth=1", rockspec.source.url, module }
   local tag_or_branch = rockspec.source.tag or rockspec.source.branch


   if tag_or_branch == "master" then tag_or_branch = nil end
   if tag_or_branch then
      if git_can_clone_by_tag(git_cmd) then


         table.insert(command, 3, "--branch=" .. tag_or_branch)
      end
   end
   if not fs.execute(_tl_table_unpack(command)) then
      return nil, "Failed cloning git repository."
   end
   ok, err = fs.change_dir(module)
   if not ok then return nil, err end
   if tag_or_branch and not git_can_clone_by_tag() then
      if not fs.execute(fs.Q(git_cmd), "checkout", tag_or_branch) then
         return nil, 'Failed to check out the "' .. tag_or_branch .. '" tag or branch.'
      end
   end


   if rockspec:format_is_at_least("3.0") then
      command = { fs.Q(git_cmd), "submodule", "update", "--init", "--recursive" }

      if git_supports_shallow_recommendations(git_cmd) then
         table.insert(command, 5, "--recommend-shallow")
      elseif git_supports_shallow_submodules(git_cmd) then

         table.insert(command, 5, "--depth=1")
      end

      if not fs.execute(_tl_table_unpack(command)) then
         return nil, 'Failed to fetch submodules.'
      end
   end

   if not rockspec.source.tag then
      rockspec.source.identifier = git_identifier(git_cmd, rockspec.version)
   end

   fs.delete(dir.path(store_dir, module, ".git"))
   fs.delete(dir.path(store_dir, module, ".gitignore"))
   fs.pop_dir()
   fs.pop_dir()
   return module, store_dir
end

return git
