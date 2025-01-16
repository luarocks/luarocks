local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_pack = table.pack or function(...) return { n = select("#", ...), ... } end; local type = type


local zip = { ZipHandle = {}, LocalFileHeader = {}, Zip = {} }












































local zlib = require("zlib")
local fs = require("luarocks.fs")
local fun = require("luarocks.fun")
local dir = require("luarocks.dir")





local function shr(n, m)
   return math.floor(n / 2 ^ m)
end

local function shl(n, m)
   return (n * 2 ^ m)
end

local function lowbits(n, m)
   return (n % 2 ^ m)
end

local function mode_to_windowbits(mode)
   if mode == "gzip" then
      return 31
   elseif mode == "zlib" then
      return 0
   elseif mode == "raw" then
      return -15
   end
end



local zlib_compress
local zlib_uncompress
local zlib_crc32
if zlib._VERSION:match("^lua%-zlib") then
   function zlib_compress(data, mode)
      return (zlib.deflate(6, mode_to_windowbits(mode))(data, "finish"))
   end

   function zlib_uncompress(data, mode)
      return (zlib.inflate(mode_to_windowbits(mode))(data))
   end

   function zlib_crc32(data)
      return zlib.crc32()(data)
   end
elseif zlib._VERSION:match("^lzlib") then
   function zlib_compress(data, mode)
      return zlib.compress(data, -1, nil, mode_to_windowbits(mode))
   end

   function zlib_uncompress(data, mode)
      return zlib.decompress(data, mode_to_windowbits(mode))
   end

   function zlib_crc32(data)
      return zlib.crc32(zlib.crc32(), data)
   end
else
   error("unknown zlib library", 0)
end

local function number_to_lestring(num, nbytes)
   local out = {}
   for _ = 1, nbytes do
      local byte = num % 256
      table.insert(out, string.char(byte))
      num = math.floor((num - byte) / 256)
   end
   return table.concat(out)
end

local function lestring_to_number(str)
   local n = 0
   local bytes = { string.byte(str, 1, #str) }
   for b = 1, #str do
      n = n + shl(bytes[b], (b - 1) * 8)
   end
   return math.floor(n)
end

local LOCAL_FILE_HEADER_SIGNATURE = number_to_lestring(0x04034b50, 4)
local DATA_DESCRIPTOR_SIGNATURE = number_to_lestring(0x08074b50, 4)
local CENTRAL_DIRECTORY_SIGNATURE = number_to_lestring(0x02014b50, 4)
local END_OF_CENTRAL_DIR_SIGNATURE = number_to_lestring(0x06054b50, 4)





local function zipwriter_open_new_file_in_zip(self, filename)
   if self.in_open_file then
      self:close_file_in_zip()
      return nil
   end
   local lfh = {}
   self.local_file_header = lfh
   lfh.last_mod_file_time = 0
   lfh.last_mod_file_date = 0
   lfh.file_name_length = #filename
   lfh.extra_field_length = 0
   lfh.file_name = filename:gsub("\\", "/")
   lfh.external_attr = shl(493, 16)
   self.in_open_file = true
   return true
end





local function zipwriter_write_file_in_zip(self, data)
   if not self.in_open_file then
      return nil
   end
   local lfh = self.local_file_header
   local compressed = zlib_compress(data, "raw")
   lfh.crc32 = zlib_crc32(data)
   lfh.compressed_size = #compressed
   lfh.uncompressed_size = #data
   self.data = compressed
   return true
end




local function zipwriter_close_file_in_zip(self)
   local zh = self.ZipHandle

   if not self.in_open_file then
      return nil
   end


   local lfh = self.local_file_header
   lfh.offset = zh:seek()
   zh:write(LOCAL_FILE_HEADER_SIGNATURE)
   zh:write(number_to_lestring(20, 2))
   zh:write(number_to_lestring(4, 2))
   zh:write(number_to_lestring(8, 2))
   zh:write(number_to_lestring(lfh.last_mod_file_time, 2))
   zh:write(number_to_lestring(lfh.last_mod_file_date, 2))
   zh:write(number_to_lestring(lfh.crc32, 4))
   zh:write(number_to_lestring(lfh.compressed_size, 4))
   zh:write(number_to_lestring(lfh.uncompressed_size, 4))
   zh:write(number_to_lestring(lfh.file_name_length, 2))
   zh:write(number_to_lestring(lfh.extra_field_length, 2))
   zh:write(lfh.file_name)


   zh:write(self.data)


   zh:write(DATA_DESCRIPTOR_SIGNATURE)
   zh:write(number_to_lestring(lfh.crc32, 4))
   zh:write(number_to_lestring(lfh.compressed_size, 4))
   zh:write(number_to_lestring(lfh.uncompressed_size, 4))

   table.insert(self.files, lfh)
   self.in_open_file = false

   return true
end



local function zipwriter_add(self, file)
   local fin
   local ok, err = self:open_new_file_in_zip(file)
   if not ok then
      err = "error in opening " .. file .. " in zipfile"
   else
      fin = io.open(fs.absolute_name(file), "rb")
      if not fin then
         ok = false
         err = "error opening " .. file .. " for reading"
      end
   end
   if ok then
      local data = fin:read("*a")
      if not data then
         err = "error reading " .. file
         ok = false
      else
         ok = self:write_file_in_zip(data)
         if not ok then
            err = "error in writing " .. file .. " in the zipfile"
         end
      end
   end
   if fin then
      fin:close()
   end
   if ok then
      ok = self:close_file_in_zip()
      if not ok then
         err = "error in writing " .. file .. " in the zipfile"
      end
   end
   return ok == true, err
end




local function zipwriter_close(self)
   local zh = self.ZipHandle

   local central_directory_offset = zh:seek()

   local size_of_central_directory = 0

   for _, lfh in ipairs(self.files) do
      zh:write(CENTRAL_DIRECTORY_SIGNATURE)
      zh:write(number_to_lestring(3, 2))
      zh:write(number_to_lestring(20, 2))
      zh:write(number_to_lestring(0, 2))
      zh:write(number_to_lestring(8, 2))
      zh:write(number_to_lestring(lfh.last_mod_file_time, 2))
      zh:write(number_to_lestring(lfh.last_mod_file_date, 2))
      zh:write(number_to_lestring(lfh.crc32, 4))
      zh:write(number_to_lestring(lfh.compressed_size, 4))
      zh:write(number_to_lestring(lfh.uncompressed_size, 4))
      zh:write(number_to_lestring(lfh.file_name_length, 2))
      zh:write(number_to_lestring(lfh.extra_field_length, 2))
      zh:write(number_to_lestring(0, 2))
      zh:write(number_to_lestring(0, 2))
      zh:write(number_to_lestring(0, 2))
      zh:write(number_to_lestring(lfh.external_attr, 4))
      zh:write(number_to_lestring(lfh.offset, 4))
      zh:write(lfh.file_name)
      size_of_central_directory = size_of_central_directory + 46 + lfh.file_name_length
   end


   zh:write(END_OF_CENTRAL_DIR_SIGNATURE)
   zh:write(number_to_lestring(0, 2))
   zh:write(number_to_lestring(0, 2))
   zh:write(number_to_lestring(#self.files, 2))
   zh:write(number_to_lestring(#self.files, 2))
   zh:write(number_to_lestring(size_of_central_directory, 4))
   zh:write(number_to_lestring(central_directory_offset, 4))
   zh:write(number_to_lestring(0, 2))
   zh:close()

   return true
end




function zip.new_zipwriter(name)

   local zw = {}

   zw.ZipHandle = io.open(fs.absolute_name(name), "wb")
   if not zw.ZipHandle then
      return nil
   end
   zw.files = {}
   zw.in_open_file = false

   zw.add = zipwriter_add
   zw.close = zipwriter_close
   zw.open_new_file_in_zip = zipwriter_open_new_file_in_zip
   zw.write_file_in_zip = zipwriter_write_file_in_zip
   zw.close_file_in_zip = zipwriter_close_file_in_zip

   return zw
end







function zip.zip(zipfile, ...)
   local zw = zip.new_zipwriter(zipfile)
   if not zw then
      return nil, "error opening " .. zipfile
   end

   local args = _tl_table_pack(...)
   local ok, err
   for i = 1, args.n do
      local file = args[i]
      if fs.is_dir(file) then
         for _, entry in ipairs(fs.find(file)) do
            local fullname = dir.path(file, entry)
            if fs.is_file(fullname) then
               ok, err = zw:add(fullname)
               if not ok then break end
            end
         end
      else
         ok, err = zw:add(file)
         if not ok then break end
      end
   end

   zw:close()
   return ok, err
end


local function ziptime_to_luatime(ztime, zdate)
   local date = {
      year = shr(zdate, 9) + 1980,
      month = shr(lowbits(zdate, 9), 5),
      day = lowbits(zdate, 5),
      hour = shr(ztime, 11),
      min = shr(lowbits(ztime, 11), 5),
      sec = lowbits(ztime, 5) * 2,
   }

   if date.month == 0 then date.month = 1 end
   if date.day == 0 then date.day = 1 end

   return date
end

local function read_file_in_zip(zh, cdr)
   local sig = zh:read(4)
   if sig ~= LOCAL_FILE_HEADER_SIGNATURE then
      return nil, "failed reading Local File Header signature"
   end



   zh:seek("cur", 22)
   local file_name_length = lestring_to_number(zh:read(2))
   local extra_field_length = lestring_to_number(zh:read(2))
   zh:read(file_name_length)
   zh:read(extra_field_length)

   local data = zh:read(cdr.compressed_size)

   local uncompressed
   if cdr.compression_method == 8 then
      uncompressed = zlib_uncompress(data, "raw")
   elseif cdr.compression_method == 0 then
      uncompressed = data
   else
      return nil, "unknown compression method " .. cdr.compression_method
   end

   if #uncompressed ~= cdr.uncompressed_size then
      return nil, "uncompressed size doesn't match"
   end
   if cdr.crc32 ~= zlib_crc32(uncompressed) then
      return nil, "crc32 failed (expected " .. cdr.crc32 .. ") - data: " .. uncompressed
   end

   return uncompressed
end

local function process_end_of_central_dir(zh)
   local at, errend = zh:seek("end", -22)
   if not at then
      return nil, errend
   end

   while true do
      local sig = zh:read(4)
      if sig == END_OF_CENTRAL_DIR_SIGNATURE then
         break
      end
      at = at - 1
      local at1 = zh:seek("set", at)
      if at1 ~= at then
         return nil, "Could not find End of Central Directory signature"
      end
   end





   zh:seek("cur", 6)

   local central_directory_entries = lestring_to_number(zh:read(2))


   zh:seek("cur", 4)

   local central_directory_offset = lestring_to_number(zh:read(4))

   return central_directory_entries, central_directory_offset
end

local function process_central_dir(zh, cd_entries)

   local files = {}

   for i = 1, cd_entries do
      local sig = zh:read(4)
      if sig ~= CENTRAL_DIRECTORY_SIGNATURE then
         return nil, "failed reading Central Directory signature"
      end

      local cdr = {}
      files[i] = cdr

      cdr.version_made_by = lestring_to_number(zh:read(2))
      cdr.version_needed = lestring_to_number(zh:read(2))
      cdr.bitflag = lestring_to_number(zh:read(2))
      cdr.compression_method = lestring_to_number(zh:read(2))
      cdr.last_mod_file_time = lestring_to_number(zh:read(2))
      cdr.last_mod_file_date = lestring_to_number(zh:read(2))
      cdr.last_mod_luatime = ziptime_to_luatime(cdr.last_mod_file_time, cdr.last_mod_file_date)
      cdr.crc32 = lestring_to_number(zh:read(4))
      cdr.compressed_size = lestring_to_number(zh:read(4))
      cdr.uncompressed_size = lestring_to_number(zh:read(4))
      cdr.file_name_length = lestring_to_number(zh:read(2))
      cdr.extra_field_length = lestring_to_number(zh:read(2))
      cdr.file_comment_length = lestring_to_number(zh:read(2))
      cdr.disk_number_start = lestring_to_number(zh:read(2))
      cdr.internal_attr = lestring_to_number(zh:read(2))
      cdr.external_attr = lestring_to_number(zh:read(4))
      cdr.offset = lestring_to_number(zh:read(4))
      cdr.file_name = zh:read(cdr.file_name_length)
      cdr.extra_field = zh:read(cdr.extra_field_length)
      cdr.file_comment = zh:read(cdr.file_comment_length)
   end
   return files
end





function zip.unzip(zipfile)
   zipfile = fs.absolute_name(zipfile)
   local zh, erropen = io.open(zipfile, "rb")
   if not zh then
      return nil, erropen
   end

   local cd_entries, cd_offset = process_end_of_central_dir(zh)
   if type(cd_offset) == "string" then
      return nil, cd_offset
   end

   local okseek, errseek = zh:seek("set", cd_offset)
   if not okseek then
      return nil, errseek
   end

   local files, errproc = process_central_dir(zh, cd_entries)
   if not files then
      return nil, errproc
   end

   for _, cdr in ipairs(files) do
      local file = cdr.file_name
      if file:sub(#file) == "/" then
         local okmake, errmake = fs.make_dir(dir.path(fs.current_dir(), file))
         if not okmake then
            return nil, errmake
         end
      else
         local base = dir.dir_name(file)
         if base ~= "" then
            base = dir.path(fs.current_dir(), base)
            if not fs.is_dir(base) then
               local okmake, errmake = fs.make_dir(base)
               if not okmake then
                  return nil, errmake
               end
            end
         end

         local okseek2, errseek2 = zh:seek("set", cdr.offset)
         if not okseek2 then
            return nil, errseek2
         end

         local contents, err = read_file_in_zip(zh, cdr)
         if not contents then
            return nil, err
         end
         local pathname = dir.path(fs.current_dir(), file)
         local wf, erropen2 = io.open(pathname, "wb")
         if not wf then
            zh:close()
            return nil, erropen2
         end
         wf:write(contents)
         wf:close()

         if cdr.external_attr > 0 then
            fs.set_permissions(pathname, "exec", "all")
         else
            fs.set_permissions(pathname, "read", "all")
         end
         fs.set_time(pathname, cdr.last_mod_luatime)
      end
   end
   zh:close()
   return true
end

function zip.gzip(input_filename, output_filename)

   if not output_filename then
      output_filename = input_filename .. ".gz"
   end

   local fn = fun.partial(fun.flip(zlib_compress), "gzip")
   return fs.filter_file(fn, input_filename, output_filename)
end

function zip.gunzip(input_filename, output_filename)

   if not output_filename then
      output_filename = input_filename:gsub("%.gz$", "")
   end

   local fn = fun.partial(fun.flip(zlib_uncompress), "gzip")
   return fs.filter_file(fn, input_filename, output_filename)
end

return zip
