local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local util = {}




local dir_sep = package.config:sub(1, 1)










function util.popen_read(cmd, spec)
   local tmpfile = (dir_sep == "\\") and
   (os.getenv("TMP") .. "/luarocks-" .. tostring(math.floor(math.random() * 10000))) or
   os.tmpname()
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


















function util.show_table(t, tname, top_indent)
   local cart
   local autoref

   local function is_empty_table(tbl) return next(tbl) == nil end

   local function basic_serialize(o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug and debug.getinfo(o, "S")
         if not info then
            return ("%q"):format(so)
         end

         if info.what == "C" then
            return ("%q"):format(so .. ", C function")
         else

            return ("%q"):format(so .. ", defined in (" .. info.linedefined .. "-" .. info.lastlinedefined .. ")" .. info.source)
         end
      elseif type(o) == "number" then
         return so
      else
         return ("%q"):format(so)
      end
   end

   local function add_to_cart(value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if not (type(value) == "table") then
         cart = cart .. " = " .. basic_serialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] .. " (self reference)\n"
            autoref = autoref .. name .. " = " .. saved[value] .. ";\n"
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

                  add_to_cart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   tname = tname or "__unnamed__"
   if type(t) ~= "table" then
      return tname .. " = " .. basic_serialize(t)
   end
   cart, autoref = "", ""
   add_to_cart(t, tname, top_indent)
   return cart .. autoref
end





function util.deep_merge(dst, src)
   for k, v in pairs(src) do
      if type(v) == "table" then
         local dstk = dst[k]
         if dstk == nil then
            dst[k] = {}
         end
         if type(dstk) == "table" then
            util.deep_merge(dst[k], v)
         else
            dst[k] = v
         end
      else
         dst[k] = v
      end
   end
end





function util.deep_merge_under(dst, src)
   for k, v in pairs(src) do
      if type(v) == "table" then
         if dst[k] == nil then
            dst[k] = {}
         end
         if type(dst[k]) == "table" then
            util.deep_merge_under(dst[k], v)
         end
      elseif dst[k] == nil then
         dst[k] = v
      end
   end
end



function util.split_string(str, delim, maxNb)

   if string.find(str, delim) == nil then
      return { str }
   end
   if maxNb == nil or maxNb < 1 then
      maxNb = 0
   end
   local result = {}
   local pat = "(.-)" .. delim .. "()"
   local nb = 0
   local lastPos
   for part, pos in string.gmatch(str, pat) do
      nb = nb + 1
      result[nb] = part
      lastPos = tonumber(pos)
      if nb == maxNb then break end
   end

   if nb ~= maxNb then
      result[nb + 1] = string.sub(str, lastPos)
   end
   return result
end











function util.cleanup_path(list, sep, lua_version, keep_first)

   list = list:gsub(dir_sep, "/")

   local parts = util.split_string(list, sep)
   local final, entries = {}, {}
   local start, stop, step

   if keep_first then
      start, stop, step = 1, #parts, 1
   else
      start, stop, step = #parts, 1, -1
   end

   for i = start, stop, step do
      local part = parts[i]:gsub("//", "/")
      if lua_version then
         part = part:gsub("/lua/([%d.]+)/", function(part_version)
            if part_version:sub(1, #lua_version) ~= lua_version then
               return "/lua/" .. lua_version .. "/"
            end
         end)
      end
      if not entries[part] then
         local at = keep_first and #final + 1 or 1
         table.insert(final, at, part)
         entries[part] = true
      end
   end

   return (table.concat(final, sep):gsub("/", dir_sep))
end




function util.keys(tbl)
   local ks = {}
   for k, _ in pairs(tbl) do
      table.insert(ks, k)
   end
   return ks
end


function util.printerr(...)
   io.stderr:write(table.concat({ ... }, "\t"))
   io.stderr:write("\n")
end



function util.warning(msg)
   util.printerr("Warning: " .. msg)
end


local function default_sort(a, b)
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











function util.sortedpairs(tbl, sort_function)

   if not sort_function then
      sort_function = default_sort
   end
   local keys = util.keys(tbl)
   local sub_orders = {}

   if type(sort_function) == "function" then
      table.sort(keys, sort_function)
   else
      local order = sort_function
      local ordered_keys = {}
      local all_keys = keys
      keys = {}

      for _, order_entry in ipairs(order) do
         local key, sub_order
         if type(order_entry) == "table" then
            key = order_entry[1]
            sub_order = order_entry[2]
         else
            key = order_entry
         end

         if tbl[key] then
            ordered_keys[key] = true
            sub_orders[key] = sub_order
            table.insert(keys, key)
         end
      end

      table.sort(all_keys, default_sort)
      for _, key in ipairs(all_keys) do
         if not ordered_keys[key] then
            table.insert(keys, key)
         end
      end
   end

   local i = 1
   return function()
      local key = keys[i]
      i = i + 1
      return key, tbl[key], sub_orders[key]
   end
end

return util
