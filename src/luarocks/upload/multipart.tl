
local record multipart
   record TableMap<K, V>
      map: {K: V}
      array: {V}
   end
end

local type TableMap = multipart.TableMap

local record File
   mimetype: string --! TEMP
   fname: string
   mime: function(File): string --! TEMP
end

-- socket.url.escape(s) from LuaSocket 3.0rc1 --?
function multipart.url_escape(s: string): string
   return (string.gsub(s, "([^A-Za-z0-9_])", function(c: string): string
      return string.format("%%%02x", string.byte(c))
   end))
end

function File.mime(self: File): string --! TEMP
   if not self.mimetype then
      local mimetypes_ok, mimetypes = pcall(require, "luarocks.upload.mimetypes")  --! TEMP
      if mimetypes_ok then
         self.mimetype = mimetypes.guess(self.fname) --! TEMP
      end
      self.mimetype = self.mimetype or "application/octet-stream" --! TEMP
   end
   return self.mimetype
end

function File:content(): string, string
   local fd = io.open(self.fname, "rb")
   if not fd then
      return nil, "Failed to open file: "..self.fname
   end
   local data = fd:read("*a")
   fd:close()
   return data
end

local function rand_string(len: integer): string
   local shuffled: {integer} = {}
   for i = 1, len do
      local r = math.random(97, 122)
      if math.random() >= 0.5 then
        r = r - 32
      end
      shuffled[i as integer] = r  --! cast because math.tointeger returns an integer?
   end
   return string.char(table.unpack(shuffled))
end

-- multipart encodes params
-- returns encoded string,boundary
-- params is an a table of tuple tables:
-- params = {
--   {key1, value2},
--   {key2, value2},
--   key3: value3
-- }
function multipart.encode(params: TableMap<string, string>): string, string --! Table map type
   local tuples = {} --! type
   for i = 1, #params.array do
      tuples[i] = params.array[i]
   end
   for k,v in pairs(params.map) do
      if k is string then
         table.insert(tuples, {k, v})
      end
   end
   local chunks: {string} = {}
   for _, tuple in ipairs(tuples) do
      local k,v = table.unpack(tuple)
      k = multipart.url_escape(k)
      local buffer: {string} = { 'Content-Disposition: form-data; name="' .. k .. '"' }
      local content: string
      if type(v) == "table" and v.__class == File then
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
   local boundary: string
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
                        "\r\n", "--", boundary, "--", "\r\n" }), boundary
end

function multipart.new_file(fname, mime)
   local self = {}
   setmetatable(self, { __index = File })
   self.__class = File
   self.fname = fname
   self.mimetype = mime
   return self
end

return multipart

