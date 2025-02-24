local lua_version = _VERSION:sub(-3)

local M = {}

local unpack = lua_version == "5.1" and unpack or table.unpack

local function addasterisk(fmt)
   if type(fmt) == "string" and fmt:sub(1, 1) ~= "*" then
      return "*"..fmt
   else
      return fmt
   end
end

function M.update_file_meta(file_meta, is_luajit52)

   -- make '*' optional for file:read and file:lines

   local file_lines = file_meta.__index.lines
   file_meta.__index.lines = function(self, ...)
      local n = select('#', ...)
      for i = 1, n do
         local a = select(i, ...)
         local b = addasterisk(a)
         -- as an optimization we only allocate a table for the
         -- modified format arguments when we have a '*' somewhere
         if a ~= b then
            local args = { ... }
            args[i] = b
            for j = i+1, n do
               args[j] = addasterisk(args[j])
            end
            return file_lines(self, unpack(args, 1, n))
         end
      end
      return file_lines(self, ...)
   end

   local file_read = file_meta.__index.read
   file_meta.__index.read = function(self, ...)
      local n = select('#', ...)
      for i = 1, n do
         local a = select(i, ...)
         local b = addasterisk(a)
         -- as an optimization we only allocate a table for the
         -- modified format arguments when we have a '*' somewhere
         if a ~= b then
            local args = { ... }
            args[i] = b
            for j = i+1, n do
               args[j] = addasterisk(args[j])
            end
            return file_read(self, unpack(args, 1, n))
         end
      end
      return file_read(self, ...)
   end

   if not is_luajit52 then
      local file_write = file_meta.__index.write
      file_meta.__index.write = function(self, ...)
         local ret, err = file_write(self, ...)
         if ret then
            return self
         end
         return ret, err
      end
   end
end

return M
