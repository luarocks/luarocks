local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack

local svn = {}


local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")










function svn.get_sources(rockspec, _extract, dest_dir)

   local svn_cmd = rockspec.variables.SVN
   local ok, err_msg = fs.is_tool_available(svn_cmd, "Subversion")
   if not ok then
      return nil, err_msg
   end

   local name_version = rockspec.name .. "-" .. rockspec.version
   local module = rockspec.source.module or dir.base_name(rockspec.source.url)
   local url = rockspec.source.url:gsub("^svn://", "")
   local command = { svn_cmd, "checkout", url, module }
   if rockspec.source.tag then
      table.insert(command, 5, "-r")
      table.insert(command, 6, rockspec.source.tag)
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
   local okchange, err = fs.change_dir(store_dir)
   if not okchange then return nil, err end
   if not fs.execute(_tl_table_unpack(command)) then
      return nil, "Failed fetching files from Subversion."
   end
   okchange, err = fs.change_dir(module)
   if not okchange then return nil, err end
   for _, d in ipairs(fs.find(".")) do
      if dir.base_name(d) == ".svn" then
         fs.delete(dir.path(store_dir, module, d))
      end
   end
   fs.pop_dir()
   fs.pop_dir()
   return module, store_dir
end


return svn
