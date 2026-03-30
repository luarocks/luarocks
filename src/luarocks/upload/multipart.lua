local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type
local multipart = { File = {} }














local File = multipart.File


function multipart.url_escape(s)
   return (string.gsub(s, "([^A-Za-z0-9_])", function(c)
      return string.format("%%%02x", string.byte(c))
   end))
end

function multipart.File:mime()
   if not self.mimetype then
      local mimetypes_ok, mimetypes = pcall(require, "mimetypes")
      if mimetypes_ok then
         self.mimetype = mimetypes.guess(self.fname)
      end
      self.mimetype = self.mimetype or "application/octet-stream"
   end
   return self.mimetype
end

function multipart.File:content()
   local fd = io.open(self.fname, "rb")
   if not fd then
      return nil, "Failed to open file: " .. self.fname
   end
   local data = fd:read("*a")
   fd:close()
   return data
end

local function rand_string(len)
   local shuffled = {}
   for i = 1, len do
      local r = math.random(97, 122)
      if math.random() >= 0.5 then
         r = r - 32
      end
      shuffled[i] = r
   end
   return string.char(_tl_table_unpack(shuffled))
end









function multipart.encode(params)
   local tuples = {}
   for k, v in pairs(params) do
      if type(k) == "string" then
         table.insert(tuples, { k, v })
      end
   end
   local chunks = {}
   for _, tuple in ipairs(tuples) do
      local k, v = _tl_table_unpack(tuple)
      k = multipart.url_escape(k)
      local buffer = { 'Content-Disposition: form-data; name="' .. k .. '"' }
      local content
      if type(v) == "table" then
         buffer[1] = buffer[1] .. ('; filename="' .. v.fname:gsub(".*[/\\]", "") .. '"')
         table.insert(buffer, "Content-type: " .. v:mime())
         content = v:content()
      else
         content = v
      end
      table.insert(buffer, "")
      table.insert(buffer, content)
      table.insert(chunks, table.concat(buffer, "\r\n"))
   end
   local boundary
   while not boundary do
      boundary = "Boundary" .. rand_string(16)
      for _, chunk in ipairs(chunks) do
         if chunk:find(boundary) then
            boundary = nil
            break
         end
      end
   end
   local inner = "\r\n--" .. boundary .. "\r\n"
   return table.concat({ "--", boundary, "\r\n",
table.concat(chunks, inner),
"\r\n", "--", boundary, "--", "\r\n", }), boundary
end

function multipart.new_file(fname, mime)
   local self = {}

   setmetatable(self, { __index = File })

   self.fname = fname
   self.mimetype = mime
   return self
end

return multipart
