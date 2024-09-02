
local record util
end

--------------------------------------------------------------------------------

local type Ordering = require("luarocks.core.types.ordering").Ordering
local type SortBy = require("luarocks.core.types.ordering").SortBy

local dir_sep = package.config:sub(1, 1)

--- Run a process and read a its output.
-- Equivalent to io.popen(cmd):read("*l"), except that it
-- closes the fd right away.
-- @param cmd string: The command to execute
-- @param spec string: "*l" by default, to read a single line.
-- May be used to read more, passing, for instance, "*a".
-- @return string: the output of the program.
function util.popen_read(cmd: string, spec?: string): string
   local tmpfile: string = (dir_sep == "\\")
                   and (os.getenv("TMP") .. "/luarocks-" .. tostring(math.floor(math.random() * 10000)))
                   or os.tmpname()
   os.execute(cmd .. " > " .. tmpfile)
   local fd = io.open(tmpfile, "rb")
   if not fd then
      os.remove(tmpfile)
      return ""
   end
   local out = fd:read(spec or "*l")
   fd:close()
   os.remove(tmpfile)
   return out or ""
end

---
-- Formats tables with cycles recursively to any depth.
-- References to other tables are shown as values.
-- Self references are indicated.
-- The string returned is "Lua code", which can be processed
-- (in the case in which indent is composed by spaces or "--").
-- Userdata and function keys and values are shown as strings,
-- which logically are exactly not equivalent to the original code.
-- This routine can serve for pretty formating tables with
-- proper indentations, apart from printing them:
-- io.write(table.show(t, "t"))   -- a typical use
-- Written by Julio Manuel Fernandez-Diaz,
-- Heavily based on "Saving tables with cycles", PIL2, p. 113.
-- @param t table: is the table.
-- @param tname string: is the name of the table (optional)
-- @param top_indent string: is a first indentation (optional).
-- @return string: the pretty-printed table
function util.show_table(t: {any:any}, tname: string, top_indent: string): string
   local cart: string     -- a container
   local autoref: string  -- for self references

   local function is_empty_table(tbl: {any:any}): boolean return next(tbl) == nil end

   local function basic_serialize(o: any): string
      local so = tostring(o)
      if o is function then
         local info = debug and debug.getinfo(o, "S")
         if not info then
            return ("%q"):format(so)
         end
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return ("%q"):format(so .. ", C function")
         else
            -- the information is defined through lines
            return ("%q"):format(so .. ", defined in (" .. info.linedefined .. "-" .. info.lastlinedefined .. ")" .. info.source)
         end
      elseif o is number then
         return so
      else
         return ("%q"):format(so)
      end
   end

   local function add_to_cart (value: any | {any:any}, name: string, indent: string, saved?: {any: string}, field?: string)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if not value is {any: any} then
         cart = cart .. " = " .. basic_serialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
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

   tname = tname or "__unnamed__"
   if not t is {any:any} then
      return tname .. " = " .. basic_serialize(t)
   end
   cart, autoref = "", ""
   add_to_cart(t, tname, top_indent)
   return cart .. autoref
end

--- Produce a Lua pattern that matches precisely the given string
-- (this is suitable to be concatenating to other patterns,
-- so it does not include beginning- and end-of-string markers (^$)
-- @param s string: The input string
-- @return string: The equivalent pattern
function util.matchquote(s: string): string
   return (s:gsub("[?%-+*%[%].%%()$^]","%%%1"))
end

--- Merges contents of src on top of dst's contents
-- (i.e. if an key from src already exists in dst, replace it).
-- @param dst Destination table, which will receive src's contents.
-- @param src Table which provides new contents to dst.
function util.deep_merge(dst: {any: any}, src: {any: any})
   for k, v in pairs(src) do
      if v is {any: any} then
         local dstk: any | {any: any} = dst[k]
         if dstk == nil then
            dst[k] = {}
            dstk = dst[k]
         end
         if dstk is {any: any} then
            util.deep_merge(dstk, v)
         else
            dst[k] = v
         end
      else
         dst[k] = v
      end
   end
end

--- Merges contents of src below those of dst's contents
-- (i.e. if an key from src already exists in dst, do not replace it).
-- @param dst Destination table, which will receive src's contents.
-- @param src Table which provides new contents to dst.
function util.deep_merge_under(dst: {any: any}, src: {any: any})
   for k, v in pairs(src) do
      if v is {any: any} then
         local dstk: any | {any: any} = dst[k]
         if dstk == nil then
            dst[k] = {}
            dstk = dst[k]
         end
         if dstk is {any: any} then
            util.deep_merge_under(dstk, v)
         end
      elseif dst[k] == nil then
         dst[k] = v
      end
   end
end

-- from http://lua-users.org/wiki/SplitJoin
-- by Philippe Lhoste
function util.split_string(str: string, delim: string, maxNb?: number): {string}
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
   local lastPos: integer
   for part, pos in string.gmatch(str, pat) do
      nb = nb + 1
      result[nb] = part
      lastPos = tonumber(pos) as integer
      if nb == maxNb then break end
   end
   -- Handle the last field
   if nb ~= maxNb then
      result[nb + 1] = string.sub(str, lastPos)
   end
   return result
end


--- Clean up a path-style string ($PATH, $LUA_PATH/package.path, etc.),
-- removing repeated entries and making sure only the relevant
-- Lua version is used.
-- Example: given ("a;b;c;a;b;d", ";"), returns "a;b;c;d".
-- @param list string: A path string (from $PATH or package.path)
-- @param sep string: The separator
-- @param lua_version (optional) string: The Lua version to use.
-- @param keep_first (optional) if true, keep first occurrence in case
-- of duplicates; otherwise keep last occurrence. The default is false.
function util.cleanup_path(list: string, sep: string, lua_version: string, keep_first: boolean): string

   list = list:gsub(dir_sep, "/")

   local parts = util.split_string(list, sep)
   local final, entries = {}, {}
   local start, stop, step: integer, integer, integer

   if keep_first then
      start, stop, step = 1, #parts, 1
   else
      start, stop, step = #parts, 1, -1
   end

   for i = start, stop, step do
      local part = parts[i]:gsub("//", "/")
      if lua_version then
         part = part:gsub("/lua/([%d.]+)/", function(part_version: string): string
            if part_version:sub(1, #lua_version) ~= lua_version then
               return "/lua/"..lua_version.."/"
            end
         end)
      end
      if not entries[part] then
         local at = keep_first and #final+1 or 1
         table.insert(final, at, part)
         entries[part] = true
      end
   end

   return (table.concat(final, sep):gsub("/", dir_sep))
end

--- Return an array of keys of a table.
-- @param tbl table: The input table.
-- @return table: The array of keys.
function util.keys<K, V>(tbl: {K: V}): {K}
   local ks = {}
   for k,_ in pairs(tbl) do
      table.insert(ks, k)
   end
   return ks
end

--- Print a line to standard error
function util.printerr(...: string | number)
   io.stderr:write(table.concat({...},"\t"))
   io.stderr:write("\n")
end

--- Display a warning message.
-- @param msg string: the warning message
function util.warning(msg: string)
   util.printerr("Warning: "..msg)
end

--- Simple sort function used as a default for util.sortedpairs.
local function default_sort(a: any, b: any): boolean
   local ta = type(a)
   local tb = type(b)
   if ta == "number" and tb == "number" then
      return tonumber(a) < tonumber(b)
   elseif ta == "number" then
      return true
   elseif tb == "number" then
      return false
   else
      return tostring(a) < tostring(b)
   end
end

--- A table iterator generator that returns elements sorted by key,
-- to be used in "for" loops.
-- @param tbl table: The table to be iterated.
-- @param sort_function function or table or nil: An optional comparison function
-- to be used by table.sort when sorting keys, or an array listing an explicit order
-- for keys. If a value itself is an array, it is taken so that the first element
-- is a string representing the field name, and the second element is a priority table
-- for that key, which is returned by the iterator as the third value after the key
-- and the value.
-- @return function: the iterator function.
function util.sortedpairs<K, V>(tbl: {K: V}, sort_by?: SortBy<K>): function(): K, V, Ordering<K>
   local keys = util.keys(tbl)
   local sub_orders: {K: Ordering<K>} = nil

   if sort_by == nil then
      table.sort(keys, default_sort)
   elseif sort_by is table.SortFunction<K> then
      table.sort(keys, sort_by)
   else
      -- sort_by is Ordering<K>

      sub_orders = sort_by.sub_orders

      local seen_ordered_key: {K: boolean} = {}

      local my_ordered_keys: {K} = {}

      for _, key in ipairs(sort_by) do
         if tbl[key] then
            seen_ordered_key[key] = true
            table.insert(my_ordered_keys, key)
         end
      end

      table.sort(keys, default_sort)

      for _, key in ipairs(keys) do
         if not seen_ordered_key[key] then
            table.insert(my_ordered_keys, key)
         end
      end

      keys = my_ordered_keys
   end

   local i = 1
   return function(): K, V, Ordering<K>
      local key = keys[i]
      i = i + 1
      return key, tbl[key], sub_orders and sub_orders[key]
   end
end

--------------------------------------------------------------------------------
-- Functions needed by luarocks.fs,
-- added here to avoid a circular dependency:
--------------------------------------------------------------------------------

-- A portable version of fs.exists that can be used at early startup,
-- before the platform has been determined and luarocks.fs has been
-- initialized.
function util.exists(file: string): boolean
   local fd, _, code = io.open(file, "r")
   if code == 13 then
      -- code 13 means "Permission denied" on both Unix and Windows
      -- io.open on folders always fails with code 13 on Windows
      return true
   end
   if fd then
      fd:close()
      return true
   end
   return false
end

function util.starts_with(s: string, prefix: string): boolean
   return s:sub(1,#prefix) == prefix
end

return util

