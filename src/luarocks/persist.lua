
--- Utility module for loading files into tables and
-- saving tables into files.
-- Implemented separately to avoid interdependencies,
-- as it is used in the bootstrapping stage of the cfg module.
module("luarocks.persist", package.seeall)

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

   local chunk, err = loadfile(filename)
   if not chunk then
      return nil, err
   end
   local result = tbl or {}
   setfenv(chunk, result)
   chunk()
   return result
end

--- Write a table as Lua code representing a table to disk
-- (that is, in curly brackets notation).
-- This function handles only numbers, strings and tables
-- are keys (tables are handled recursively).
-- @param out userdata: a file object, open for writing.
-- @param tbl table: the table to be written.
local function write_table(out, tbl, level)
   out:write("{")
   local size = table.getn(tbl)
   local sep = "\n"
   local indent = true
   local i = 1
   for k, v in pairs(tbl) do
      out:write(sep)
      if indent then
         for n = 1,level do out:write("  ") end
      end
      sep = ",\n"
      indent = true
      if type(k) == "number" then
         if k ~= i then
            out:write(tostring(k).."=")
         else
            i = i + 1
         end
         indent = false
         sep = ", "
      elseif type(k) == "table" then
         out:write("[")
         write_table(out, k, level + 1)
         out:write("]=")
      else
         if k:match("^[a-z_]+$") then
            out:write(k.."=")
         else
            out:write("['"..k:gsub("'", "\\'").."']=") 
         end
      end
      if type(v) == "table" then
         write_table(out, v, level + 1)
      elseif type(v) == "string" then
         out:write("'"..v:gsub("'", "\\'").."'")
      else
         out:write(tostring(v))
      end
   end
   if sep ~= "\n" then
      out:write("\n")
      for n = 1,level-1 do out:write("  ") end
   end
   out:write("}")
end

--- Save the contents of a table in a file.
-- Each element of the table is saved as a global assignment.
-- Only numbers, strings and tables (containing numbers, strings
-- or other recursively processed tables) are supported.
-- @return boolean or (nil, string): true if successful, or nil and a
-- message in case of errors.
function save_from_table(filename, tbl)
   local out = io.open(filename, "w")
   if not out then
      return nil, "Cannot create file at "..filename
   end
   for k, v in pairs(tbl) do
      out:write(k.." = ")
      write_table(out, v, 1)
      out:write("\n")
   end
   out:close()
   return true
end
