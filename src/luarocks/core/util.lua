
local util = {}

local require = nil
--------------------------------------------------------------------------------

--- Run a process and read a its output.
-- Equivalent to io.popen(cmd):read("*l"), except that it 
-- closes the fd right away.
-- @param cmd string: The command to execute
-- @param spec string: "*l" by default, to read a single line.
-- May be used to read more, passing, for instance, "*a".
-- @return string: the output of the program.
function util.popen_read(cmd, spec)
   local fd = io.popen(cmd)
   local out = fd:read(spec or "*l")
   fd:close()
   return out
end

--- Create a new shallow copy of a table: a new table with
-- the same keys and values. Keys point to the same objects as
-- the original table (ie, does not copy recursively).
-- @param tbl table: the input table
-- @return table: a new table with the same contents.
function util.make_shallow_copy(tbl)
   local copy = {}
   for k,v in pairs(tbl) do
      copy[k] = v
   end
   return copy
end

---
-- Formats tables with cycles recursively to any depth.
-- References to other tables are shown as values.
-- Self references are indicated.
-- The string returned is "Lua code", which can be procesed
-- (in the case in which indent is composed by spaces or "--").
-- Userdata and function keys and values are shown as strings,
-- which logically are exactly not equivalent to the original code.
-- This routine can serve for pretty formating tables with
-- proper indentations, apart from printing them:
-- io.write(table.show(t, "t"))   -- a typical use
-- Written by Julio Manuel Fernandez-Diaz,
-- Heavily based on "Saving tables with cycles", PIL2, p. 113.
-- @param t table: is the table.
-- @param name string: is the name of the table (optional)
-- @param indent string: is a first indentation (optional).
-- @return string: the pretty-printed table
function util.show_table(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   local function is_empty_table(t) return next(t) == nil end
   
   local function basic_serialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return ("%q"):format(so .. ", C function")
         else 
            -- the information is defined through lines
            return ("%q"):format(so .. ", defined in (" .. info.linedefined .. "-" .. info.lastlinedefined .. ")" .. info.source)
         end
      elseif type(o) == "number" then
         return so
      else
         return ("%q"):format(so)
      end
   end
   
   local function add_to_cart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name
      
      cart = cart .. indent .. field
      
      if type(value) ~= "table" then
         cart = cart .. " = " .. basic_serialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if is_empty_table(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basic_serialize(k)
                  local fname = ("%s[%s]"):format(name, k)
                  field = ("[%s]"):format(k)
                  -- three spaces between levels
                  add_to_cart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end
   
   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basic_serialize(t)
   end
   cart, autoref = "", ""
   add_to_cart(t, name, indent)
   return cart .. autoref
end

--- Merges contents of src on top of dst's contents.
-- @param dst Destination table, which will receive src's contents.
-- @param src Table which provides new contents to dst.
-- @see platform_overrides
function util.deep_merge(dst, src)
   for k, v in pairs(src) do
      if type(v) == "table" then
         if not dst[k] then
            dst[k] = {}
         end
         if type(dst[k]) == "table" then
            util.deep_merge(dst[k], v)
         else
            dst[k] = v
         end
      else
         dst[k] = v
      end
   end
end

--- Remove repeated entries from a path-style string.
-- Example: given ("a;b;c;a;b;d", ";"), returns "a;b;c;d".
-- @param list string: A path string (from $PATH or package.path)
-- @param sep string: The separator
function util.remove_path_dupes(list, sep)
   assert(type(list) == "string")
   assert(type(sep) == "string")
   local parts = util.split_string(list, sep)
   local final, entries = {}, {}
   for _, part in ipairs(parts) do
      part = part:gsub("//", "/")
      if not entries[part] then
         table.insert(final, part)
         entries[part] = true
      end
   end
   return table.concat(final, sep)
end

-- from http://lua-users.org/wiki/SplitJoin
-- by Philippe Lhoste
function util.split_string(str, delim, maxNb)
   -- Eliminate bad cases...
   if string.find(str, delim) == nil then
      return { str }
   end
   if maxNb == nil or maxNb < 1 then
      maxNb = 0    -- No limit
   end
   local result = {}
   local pat = "(.-)" .. delim .. "()"
   local nb = 0
   local lastPos
   for part, pos in string.gmatch(str, pat) do
      nb = nb + 1
      result[nb] = part
      lastPos = pos
      if nb == maxNb then break end
   end
   -- Handle the last field
   if nb ~= maxNb then
      result[nb + 1] = string.sub(str, lastPos)
   end
   return result
end

--- Return an array of keys of a table.
-- @param tbl table: The input table.
-- @return table: The array of keys.
function util.keys(tbl)
   local ks = {}
   for k,_ in pairs(tbl) do
      table.insert(ks, k)
   end
   return ks
end

--- Print a line to standard error
function util.printerr(...)
   io.stderr:write(table.concat({...},"\t"))
   io.stderr:write("\n")
end

return util

