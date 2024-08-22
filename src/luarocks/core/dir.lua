local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local dir = {}



local dir_sep = package.config:sub(1, 1)

local function unquote(c)
   local first, last = c:sub(1, 1), c:sub(-1)
   if (first == '"' and last == '"') or
      (first == "'" and last == "'") then
      return c:sub(2, -2)
   end
   return c
end






function dir.split_url(url)

   url = unquote(url)
   local protocol, pathname = url:match("^([^:]*)://(.*)")
   if not protocol then
      protocol = "file"
      pathname = url
   end
   return protocol, pathname
end







function dir.normalize(name)
   local protocol, pathname = dir.split_url(name)
   pathname = pathname:gsub("\\", "/"):gsub("(.)/*$", "%1"):gsub("//", "/")
   local pieces = {}
   local drive = ""
   if pathname:match("^.:") then
      drive, pathname = pathname:match("^(.:)(.*)$")
   end
   pathname = pathname .. "/"
   for piece in pathname:gmatch("(.-)/") do
      if piece == ".." then
         local prev = pieces[#pieces]
         if not prev or prev == ".." then
            table.insert(pieces, "..")
         elseif prev ~= "" then
            table.remove(pieces)
         end
      elseif piece ~= "." then
         table.insert(pieces, piece)
      end
   end
   if #pieces == 0 then
      pathname = drive .. "."
   elseif #pieces == 1 and pieces[1] == "" then
      pathname = drive .. "/"
   else
      pathname = drive .. table.concat(pieces, "/")
   end
   if protocol ~= "file" then
      pathname = protocol .. "://" .. pathname
   else
      pathname = pathname:gsub("/", dir_sep)
   end
   return pathname
end











function dir.path(...)
   local t = { ... }
   while t[1] == "" do
      table.remove(t, 1)
   end
   for i, c in ipairs(t) do
      t[i] = unquote(c)
   end
   return dir.normalize(table.concat(t, "/"))
end

return dir
