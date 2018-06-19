
--- Utility module for loading files into tables and
-- saving tables into files.
-- Implemented separately to avoid interdependencies,
-- as it is used in the bootstrapping stage of the cfg module.
local persist = {}

local core = require("luarocks.core.persist")
local util = require("luarocks.util")

persist.load_into_table = core.load_into_table

local write_table

--- Write a value as Lua code.
-- This function handles only numbers and strings, invoking write_table
-- to write tables.
-- @param out table or userdata: a writer object supporting :write() method.
-- @param v: the value to be written.
-- @param level number: the indentation level
-- @param sub_order table: optional prioritization table
-- @see write_table
local function write_value(out, v, level, sub_order)
   if type(v) == "table" then
      write_table(out, v, level + 1, sub_order)
   elseif type(v) == "string" then
      if v:match("[\r\n]") then
         local open, close = "[[", "]]"
         local equals = 0
         local v_with_bracket = v.."]"
         while v_with_bracket:find(close, 1, true) do
            equals = equals + 1
            local eqs = ("="):rep(equals)
            open, close = "["..eqs.."[", "]"..eqs.."]"
         end
         out:write(open.."\n"..v..close)
      else
         out:write(("%q"):format(v))
      end
   else
      out:write(tostring(v))
   end
end

--- Write a table as Lua code in curly brackets notation to a writer object.
-- Only numbers, strings and tables (containing numbers, strings
-- or other recursively processed tables) are supported.
-- @param out table or userdata: a writer object supporting :write() method.
-- @param tbl table: the table to be written.
-- @param level number: the indentation level
-- @param field_order table: optional prioritization table
write_table = function(out, tbl, level, field_order)
   out:write("{")
   local sep = "\n"
   local indentation = "   "
   local indent = true
   local i = 1
   for k, v, sub_order in util.sortedpairs(tbl, field_order) do
      out:write(sep)
      if indent then
         for _ = 1, level do out:write(indentation) end
      end

      if k == i then
         i = i + 1
      else
         if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
            out:write(k)
         else
            out:write("[")
            write_value(out, k, level)
            out:write("]")
         end

         out:write(" = ")
      end

      write_value(out, v, level, sub_order)
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

--- Write a table as series of assignments to a writer object.
-- @param out table or userdata: a writer object supporting :write() method.
-- @param tbl table: the table to be written.
-- @param field_order table: optional prioritization table
local function write_table_as_assignments(out, tbl, field_order)
   for k, v, sub_order in util.sortedpairs(tbl, field_order) do
      out:write(k.." = ")
      write_value(out, v, 0, sub_order)
      out:write("\n")
   end
end

--- Write a table as series of assignments to a writer object.
-- @param out table or userdata: a writer object supporting :write() method.
-- @param tbl table: the table to be written.
local function write_table_as_table(out, tbl)
   out:write("return {\n")
   for k, v, sub_order in util.sortedpairs(tbl) do
      out:write("   " .. k .. " = ")
      write_value(out, v, 1, sub_order)
      out:write(",\n")
   end
   out:write("}\n")
end

--- Save the contents of a table to a string.
-- Each element of the table is saved as a global assignment.
-- Only numbers, strings and tables (containing numbers, strings
-- or other recursively processed tables) are supported.
-- @param tbl table: the table containing the data to be written
-- @param field_order table: an optional array indicating the order of top-level fields.
-- @return string
function persist.save_from_table_to_string(tbl, field_order)
   local out = {buffer = {}}
   function out:write(data) table.insert(self.buffer, data) end
   write_table_as_assignments(out, tbl, field_order)
   return table.concat(out.buffer)
end

--- Save the contents of a table in a file.
-- Each element of the table is saved as a global assignment.
-- Only numbers, strings and tables (containing numbers, strings
-- or other recursively processed tables) are supported.
-- @param filename string: the output filename
-- @param tbl table: the table containing the data to be written
-- @param field_order table: an optional array indicating the order of top-level fields.
-- @return boolean or (nil, string): true if successful, or nil and a
-- message in case of errors.
function persist.save_from_table(filename, tbl, field_order)
   local out = io.open(filename, "w")
   if not out then
      return nil, "Cannot create file at "..filename
   end
   write_table_as_assignments(out, tbl, field_order)
   out:close()
   return true
end

--- Save the contents of a table as a module.
-- Each element of the table is saved as a global assignment.
-- Only numbers, strings and tables (containing numbers, strings
-- or other recursively processed tables) are supported.
-- @param filename string: the output filename
-- @param tbl table: the table containing the data to be written
-- @return boolean or (nil, string): true if successful, or nil and a
-- message in case of errors.
function persist.save_as_module(filename, tbl)
   local out = io.open(filename, "w")
   if not out then
      return nil, "Cannot create file at "..filename
   end
   write_table_as_table(out, tbl)
   out:close()
   return true
end

return persist
