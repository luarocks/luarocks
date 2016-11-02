
--- Utility module for loading files into tables and
-- saving tables into files.
-- Implemented separately to avoid interdependencies,
-- as it is used in the bootstrapping stage of the cfg module.
local persist = {}
package.loaded["luarocks.persist"] = persist

local util = require("luarocks.util")

--- Load and run a Lua file in an environment.
-- @param filename string: the name of the file.
-- @param env table: the environment table.
-- @return (true, any) or (nil, string, string): true and the return value
-- of the file, or nil, an error message and an error code ("open", "load"
-- or "run") in case of errors.
local function run_file(filename, env)
   local fd, err = io.open(filename)
   if not fd then
      return nil, err, "open"
   end
   local str, err = fd:read("*a")
   fd:close()
   if not str then
      return nil, err, "open"
   end
   str = str:gsub("^#![^\n]*\n", "")
   local chunk, ran
   if _VERSION == "Lua 5.1" then -- Lua 5.1
      chunk, err = loadstring(str, filename)
      if chunk then
         setfenv(chunk, env)
         ran, err = pcall(chunk)
      end
   else -- Lua 5.2
      chunk, err = load(str, filename, "t", env)
      if chunk then
         ran, err = pcall(chunk)
      end
   end
   if not chunk then
      return nil, "Error loading file: "..err, "load"
   end
   if not ran then
      return nil, "Error running file: "..err, "run"
   end
   return true, err
end

--- Load a Lua file containing assignments, storing them in a table.
-- The global environment is not propagated to the loaded file.
-- @param filename string: the name of the file.
-- @param tbl table or nil: if given, this table is used to store
-- loaded values.
-- @return (table, table) or (nil, string, string): a table with the file's assignments
-- as fields and set of undefined globals accessed in file,
-- or nil, an error message and an error code ("open"; couldn't open the file,
-- "load"; compile-time error, or "run"; run-time error)
-- in case of errors.
function persist.load_into_table(filename, tbl)
   assert(type(filename) == "string")
   assert(type(tbl) == "table" or not tbl)

   local result = tbl or {}
   local globals = {}
   local globals_mt = {
      __index = function(t, k)
         globals[k] = true
      end
   }
   local save_mt = getmetatable(result)
   setmetatable(result, globals_mt)
   
   local ok, err, errcode = run_file(filename, result)
   
   setmetatable(result, save_mt)

   if not ok then
      return nil, err, errcode
   end
   return result, globals
end

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
         for n = 1,level do out:write(indentation) end
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
      for n = 1,level-1 do out:write(indentation) end
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

return persist
