
--- Utility module for loading files into tables and
-- saving tables into files.
-- Implemented separately to avoid interdependencies,
-- as it is used in the bootstrapping stage of the cfg module.
module("luarocks.persist", package.seeall)

local util = require("luarocks.util")

--- Load a Lua file containing assignments, storing them in a table.
-- The global environment is not propagated to the loaded file.
-- @param filename string: the name of the file.
-- @param tbl table or nil: if given, this table is used to store
-- loaded values.
-- @return table or (nil, string): a table with the file's assignments
-- as fields, or nil and a message in case of errors.
function load_into_table(filename, tbl)
   assert(type(filename) == "string")
   assert(type(tbl) == "table" or not tbl)

   local result, chunk, ran, err
   local result = tbl or {}
   if setfenv then -- Lua 5.1
      chunk, err = loadfile(filename)
      if chunk then
         setfenv(chunk, result)
         ran, err = pcall(chunk)
      end
   else -- Lua 5.2
      chunk, err = loadfile(filename, "t", result)
      if chunk then
         ran, err = pcall(chunk)
      end
   end
   
   if not chunk then
      if err:sub(1,5) ~= filename:sub(1,5) then
         return false, err
      end
      return nil, "Error loading file: "..err
   end
   if not ran then
      return nil, "Error running file: "..err
   end
   return result
end

local write_table

--- Write a value as Lua code, invoking write_table.
-- This function handles only numbers, strings and tables
-- are keys (tables are handled recursively).
-- @param out userdata: a file object, open for writing.
-- @param v: the value to be written.
-- @param level number: the indentation level
-- @param sub_order table: optional prioritization table
-- @see write_table
local function write_value(out, v, level, sub_order)
   if type(v) == "table" then
      write_table(out, v, level + 1, sub_order)
   elseif type(v) == "string" then
      if v:match("\n") then
         local open, close = "[[", "]]"
         local equals = 0
         while v:find(open,1,true) or v:find(close,1,true) do
            equals = equals + 1
            local eqs = ("="):rep(equals)
            open, close = "["..eqs.."[", "]"..eqs.."]"
         end
         out:write(open.."\n"..v..close)
      else
         out:write("\""..v:gsub("\"", "\\\"").."\"")
      end
   else
      out:write(tostring(v))
   end
end

--- Write a table as Lua code representing a table to disk
-- (that is, in curly brackets notation).
-- This function handles only numbers, strings and tables
-- are keys (tables are handled recursively).
-- @param out userdata: a file object, open for writing.
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
         for n = 1,level do out:write(indentation) end
      end
      sep = ",\n"
      indent = true
      if type(k) == "number" then
         if k ~= i then
            out:write("["..tostring(k).."]=")
         else
            i = i + 1
         end
         indent = false
         sep = ", "
      elseif type(k) == "table" then
         out:write("[")
         write_table(out, k, level + 1)
         out:write("] = ")
      else
         if k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
            out:write(k.." = ")
         else
            out:write("['"..k:gsub("'", "\\'").."'] = ") 
         end
      end
      write_value(out, v, level, sub_order)
   end
   if sep ~= "\n" then
      out:write("\n")
      for n = 1,level-1 do out:write(indentation) end
   end
   out:write("}")
end

--- Writes a table to an io-like object.
-- @param out userdata: a file object, open for writing.
-- @param tbl table: the table to be written.
-- @param field_order table: optional prioritization table
-- @return userdata The file object originally passed in as the `out` parameter.
local function write_table(out, tbl, field_order)
   for k, v, sub_order in util.sortedpairs(tbl, field_order) do
      out:write(k.." = ")
      write_value(out, v, 0, sub_order)
      out:write("\n")
   end
   return out
end

--- Save the contents of a table to a string.
-- Each element of the table is saved as a global assignment.
-- Only numbers, strings and tables (containing numbers, strings
-- or other recursively processed tables) are supported.
-- @param tbl table: the table containing the data to be written
-- @param field_order table: an optional array indicating the order of top-level fields.
-- @return string
function save_from_table_to_string(tbl, field_order)
   local out = {buffer = {}}
   function out:write(data) table.insert(self.buffer, data) end
   write_table(out, tbl, field_order)
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
function save_from_table(filename, tbl, field_order)
   local out = io.open(filename, "w")
   if not out then
      return nil, "Cannot create file at "..filename
   end
   write_table(out, tbl, field_order)
   out:close()
   return true
end
