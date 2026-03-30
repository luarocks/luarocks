local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack

local hg = {}


local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")










function hg.get_sources(rockspec, _extract, dest_dir)

   local hg_cmd = rockspec.variables.HG
   local ok_available, err_msg = fs.is_tool_available(hg_cmd, "Mercurial")
   if not ok_available then
      return nil, err_msg
   end

   local name_version = rockspec.name .. "-" .. rockspec.version

   local url = rockspec.source.url:gsub("^hg://", "")

   local module = dir.base_name(url)

   local command = { hg_cmd, "clone", url, module }
   local tag_or_branch = rockspec.source.tag or rockspec.source.branch
   if tag_or_branch then
      command = { hg_cmd, "clone", "--rev", tag_or_branch, url, module }
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
   local ok, err = fs.change_dir(store_dir)
   if not ok then return nil, err end
   if not fs.execute(_tl_table_unpack(command)) then
      return nil, "Failed cloning hg repository."
   end
   ok, err = fs.change_dir(module)
   if not ok then return nil, err end

   fs.delete(dir.path(store_dir, module, ".hg"))
   fs.delete(dir.path(store_dir, module, ".hgignore"))
   fs.pop_dir()
   fs.pop_dir()
   return module, store_dir
end


return hg
