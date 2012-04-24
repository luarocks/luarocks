
--- A Lua implementation of .zip file archiving (used for creating .rock files),
-- using only lua-zlib.
module("luarocks.tools.zip", package.seeall)

local zlib = require("zlib")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")

local function number_to_bytestring(number, nbytes)
   local out = {}
   for i = 1, nbytes do
      local byte = number % 256
      table.insert(out, string.char(byte))
      number = (number - byte) / 256
   end
   return table.concat(out)
end

--- Begin a new file to be stored inside the zipfile.
-- @param self handle of the zipfile being written.
-- @param filename filenome of the file to be added to the zipfile.
-- @return true if succeeded, nil in case of failure.
local function zipwriter_open_new_file_in_zip(self, filename)
   if self.in_open_file then
      self:close_file_in_zip()
      return nil
   end
   local lfh = {}
   self.local_file_header = lfh
   lfh.last_mod_file_time = 0 -- TODO
   lfh.last_mod_file_date = 0 -- TODO
   lfh.crc32 = 0 -- initial value
   lfh.compressed_size = 0 -- unknown yet
   lfh.uncompressed_size = 0 -- unknown yet
   lfh.file_name_length = #filename
   lfh.extra_field_length = 0
   lfh.file_name = filename:gsub("\\", "/")
   lfh.external_attr = 0 -- TODO properly store permissions
   self.in_open_file = true
   self.data = {}
   return true
end

--- Write data to the file currently being stored in the zipfile.
-- @param self handle of the zipfile being written.
-- @param buf string containing data to be written.
-- @return true if succeeded, nil in case of failure.
local function zipwriter_write_file_in_zip(self, buf)
   if not self.in_open_file then
      return nil
   end
   local lfh = self.local_file_header
   local cbuf = zlib.compress(buf):sub(3, -5)
   lfh.crc32 = zlib.crc32(lfh.crc32, buf)
   lfh.compressed_size = lfh.compressed_size + #cbuf
   lfh.uncompressed_size = lfh.uncompressed_size + #buf
   table.insert(self.data, cbuf)
   return true
end

--- Complete the writing of a file stored in the zipfile.
-- @param self handle of the zipfile being written.
-- @return true if succeeded, nil in case of failure.
local function zipwriter_close_file_in_zip(self)
   local zh = self.ziphandle
   
   if not self.in_open_file then
      return nil
   end

   -- Local file header
   local lfh = self.local_file_header
   lfh.offset = zh:seek()
   zh:write(number_to_bytestring(0x04034b50, 4)) -- signature
   zh:write(number_to_bytestring(20, 2)) -- version needed to extract: 2.0
   zh:write(number_to_bytestring(0, 2)) -- general purpose bit flag
   zh:write(number_to_bytestring(8, 2)) -- compression method: deflate
   zh:write(number_to_bytestring(lfh.last_mod_file_time, 2))
   zh:write(number_to_bytestring(lfh.last_mod_file_date, 2))
   zh:write(number_to_bytestring(lfh.crc32, 4))
   zh:write(number_to_bytestring(lfh.compressed_size, 4))
   zh:write(number_to_bytestring(lfh.uncompressed_size, 4))
   zh:write(number_to_bytestring(lfh.file_name_length, 2))
   zh:write(number_to_bytestring(lfh.extra_field_length, 2))
   zh:write(lfh.file_name)

   -- File data   
   for _, cbuf in ipairs(self.data) do
      zh:write(cbuf)
   end
   
   -- Data descriptor
   zh:write(number_to_bytestring(lfh.crc32, 4))
   zh:write(number_to_bytestring(lfh.compressed_size, 4))
   zh:write(number_to_bytestring(lfh.uncompressed_size, 4))
   
   table.insert(self.files, lfh)
   self.in_open_file = false
   
   return true
end

-- @return boolean or (boolean, string): true on success,
-- false and an error message on failure.
local function zipwriter_add(self, file)
   local fin
   local ok, err = self:open_new_file_in_zip(file)
   if not ok then
      err = "error in opening "..file.." in zipfile"
   else
      fin = io.open(fs.absolute_name(file), "rb")
      if not fin then
         ok = false
         err = "error opening "..file.." for reading"
      end
   end
   if ok then
      local buf = fin:read("*a")
      if not buf then
         err = "error reading "..file
         ok = false
      else
         ok = self:write_file_in_zip(buf)
         if not ok then
            err = "error in writing "..file.." in the zipfile"
         end
      end
   end
   if fin then
      fin:close()
   end
   if ok then
      ok = self:close_file_in_zip()
      if not ok then
         err = "error in writing "..file.." in the zipfile"
      end
   end
   return ok == true, err
end

--- Complete the writing of the zipfile.
-- @param self handle of the zipfile being written.
-- @return true if succeeded, nil in case of failure.
local function zipwriter_close(self)
   local zh = self.ziphandle
   
   local central_directory_offset = zh:seek()
   
   local size_of_central_directory = 0
   -- Central directory structure
   for _, lfh in ipairs(self.files) do
      zh:write(number_to_bytestring(0x02014b50, 4)) -- signature
      zh:write(number_to_bytestring(3, 2)) -- version made by: UNIX
      zh:write(number_to_bytestring(20, 2)) -- version needed to extract: 2.0
      zh:write(number_to_bytestring(0, 2)) -- general purpose bit flag
      zh:write(number_to_bytestring(8, 2)) -- compression method: deflate
      zh:write(number_to_bytestring(lfh.last_mod_file_time, 2))
      zh:write(number_to_bytestring(lfh.last_mod_file_date, 2))
      zh:write(number_to_bytestring(lfh.crc32, 4))
      zh:write(number_to_bytestring(lfh.compressed_size, 4))
      zh:write(number_to_bytestring(lfh.uncompressed_size, 4))
      zh:write(number_to_bytestring(lfh.file_name_length, 2))
      zh:write(number_to_bytestring(lfh.extra_field_length, 2))
      zh:write(number_to_bytestring(0, 2)) -- file comment length
      zh:write(number_to_bytestring(0, 2)) -- disk number start
      zh:write(number_to_bytestring(0, 2)) -- internal file attributes
      zh:write(number_to_bytestring(lfh.external_attr, 4)) -- external file attributes
      zh:write(number_to_bytestring(lfh.offset, 4)) -- relative offset of local header
      zh:write(lfh.file_name)
      size_of_central_directory = size_of_central_directory + 46 + lfh.file_name_length
   end
   
   -- End of central directory record
   zh:write(number_to_bytestring(0x06054b50, 4)) -- signature
   zh:write(number_to_bytestring(0, 2)) -- number of this disk
   zh:write(number_to_bytestring(0, 2)) -- number of disk with start of central directory
   zh:write(number_to_bytestring(#self.files, 2)) -- total number of entries in the central dir on this disk
   zh:write(number_to_bytestring(#self.files, 2)) -- total number of entries in the central dir
   zh:write(number_to_bytestring(size_of_central_directory, 4))
   zh:write(number_to_bytestring(central_directory_offset, 4))
   zh:write(number_to_bytestring(0, 2)) -- zip file comment length
   zh:close()

   return true
end

--- Return a zip handle open for writing.
-- @param name filename of the zipfile to be created.
-- @return a zip handle, or nil in case of error.
function new_zipwriter(name)
   
   local zw = {}
  
   zw.ziphandle = io.open(fs.absolute_name(name), "wb")
   if not zw.ziphandle then
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

--- Compress files in a .zip archive.
-- @param zipfile string: pathname of .zip archive to be created.
-- @param ... Filenames to be stored in the archive are given as
-- additional arguments.
-- @return boolean or (boolean, string): true on success,
-- false and an error message on failure.
function zip(zipfile, ...)
   local zw = new_zipwriter(zipfile)
   if not zw then
      return nil, "error opening "..zipfile
   end

   local ok, err
   for _, file in pairs({...}) do
      if fs.is_dir(file) then
         for _, entry in pairs(fs.find(file)) do
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

   local ok = zw:close()
   if not ok then
      return false, "error closing "..zipfile
   end
   return ok, err
end

