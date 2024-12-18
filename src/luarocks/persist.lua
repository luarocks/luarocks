local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type


local persist = {}









local core = require("luarocks.core.persist")
local util = require("luarocks.util")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")









persist.run_file = core.run_file
persist.load_into_table = core.load_into_table

local write_table









function persist.write_value(out, v, level, sub_order)
   if type(v) == "table" then
      level = level or 0
      write_table(out, v, level + 1, sub_order)
   elseif type(v) == "string" then
      if v:match("[\r\n]") then
         local open, close = "[[", "]]"
         local equals = 0
         local v_with_bracket = v .. "]"
         while v_with_bracket:find(close, 1, true) do
            equals = equals + 1
            local eqs = ("="):rep(equals)
            open, close = "[" .. eqs .. "[", "]" .. eqs .. "]"
         end
         out:write(open .. "\n" .. v .. close)
      else
         out:write(("%q"):format(v))
      end
   else
      out:write(tostring(v))
   end
end

local is_valid_plain_key
do
   local keywords = {
      ["and"] = true,
      ["break"] = true,
      ["do"] = true,
      ["else"] = true,
      ["elseif"] = true,
      ["end"] = true,
      ["false"] = true,
      ["for"] = true,
      ["function"] = true,
      ["goto"] = true,
      ["if"] = true,
      ["in"] = true,
      ["local"] = true,
      ["nil"] = true,
      ["not"] = true,
      ["or"] = true,
      ["repeat"] = true,
      ["return"] = true,
      ["then"] = true,
      ["true"] = true,
      ["until"] = true,
      ["while"] = true,
   }
   function is_valid_plain_key(k)
      return k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") and
      not keywords[k]
   end
end

local function write_table_key_assignment(out, k, level)
   if type(k) == "string" and is_valid_plain_key(k) then
      out:write(k)
   else
      out:write("[")
      persist.write_value(out, k, level)
      out:write("]")
   end

   out:write(" = ")
end








write_table = function(out, tbl, level, sort_by)
   out:write("{")
   local sep = "\n"
   local indentation = "   "
   local indent = true
   local i = 1
   for k, v, sub_order in util.sortedpairs(tbl, sort_by) do
      out:write(sep)
      if indent then
         for _ = 1, level do out:write(indentation) end
      end

      if type(k) == "number" then
         i = i + 1
      else
         write_table_key_assignment(out, k, level)
      end

      persist.write_value(out, v, level, sub_order)
      if type(v) == "number" then
         sep = ", "
         indent = false
      else
         sep = ",\n"
         indent = true
      end
   end
   if sep ~= "\n" then
      out:write("\n")
      for _ = 1, level - 1 do out:write(indentation) end
   end
   out:write("}")
end






local function write_table_as_assignments(out, tbl, sort_by)
   for k, v, sub_order in util.sortedpairs(tbl, sort_by) do
      if not (type(k) == "string" and is_valid_plain_key(k)) then
         return nil, "cannot store '" .. tostring(k) .. "' as a plain key."
      end
      out:write(k .. " = ")
      persist.write_value(out, v, 0, sub_order)
      out:write("\n")
   end
   return true
end




local function write_table_as_table(out, tbl)
   out:write("return {\n")
   for k, v, sub_order in util.sortedpairs(tbl) do
      out:write("   ")
      write_table_key_assignment(out, k, 1)
      persist.write_value(out, v, 1, sub_order)
      out:write(",\n")
   end
   out:write("}\n")
end








function persist.save_from_table_to_string(tbl, sort_by)
   local out = { buffer = {} }
   function out:write(data) table.insert(self.buffer, data) end
   local ok, err = write_table_as_assignments(out, tbl, sort_by)
   if not ok then
      return nil, err
   end
   return table.concat(out.buffer)
end










function persist.save_from_table(filename, tbl, sort_by)
   local prefix = dir.dir_name(filename)
   fs.make_dir(prefix)
   local out = io.open(filename, "w")
   if not out then
      return nil, "Cannot create file at " .. filename
   end
   local ok, err = write_table_as_assignments(out, tbl, sort_by)
   out:close()
   if not ok then
      return nil, err
   end
   return true
end









function persist.save_as_module(filename, tbl)
   local out = io.open(filename, "w")
   if not out then
      return nil, "Cannot create file at " .. filename
   end
   write_table_as_table(out, tbl)
   out:close()
   return true
end

function persist.load_config_file_if_basic(filename, config)
   local env = {
      home = config.home,
   }
   local result, _, errcode = persist.load_into_table(filename, env)
   if errcode == "load" or errcode == "run" then

      return nil, "Could not read existing config file " .. filename
   end

   local tbl
   if errcode == "open" then

      tbl = {}
   else
      tbl = result
      tbl.home = nil
   end

   return tbl
end

function persist.save_default_lua_version(prefix, lua_version)
   local ok, err_makedir = fs.make_dir(prefix)
   if not ok then
      return nil, err_makedir
   end
   local fd, err_open = io.open(dir.path(prefix, "default-lua-version.lua"), "w")
   if not fd then
      return nil, err_open
   end
   fd:write('return "' .. lua_version .. '"\n')
   fd:close()
   return true
end

return persist
