
module("luarocks.tools.zip", package.seeall)

local zlib = require "zlib"

local function number_to_bytestring(number, nbytes)
   local out = {}
   for i = 1, nbytes do
      local byte = number % 256
      table.insert(out, string.char(byte))
      number = (number - byte) / 256
   end
   return table.concat(out)
end

--- Return a zip handle open for writing.
-- @param name filename of the zipfile to be created.
-- @return a zip handle, or nil in case of error.
function write_open(name)
   
   local zf = {}
  
   zf.ziphandle = io.open(name, "w")
   if not zf.ziphandle then
      return nil
   end
   zf.files = {}
   zf.in_open_file = false

   return zf
end

--- Begin a new file to be stored inside the zipfile.
-- @param zf handle of the zipfile being written.
-- @param filename filenome of the file to be added to the zipfile.
-- @return true if succeeded, nil in case of failure.
function write_open_new_file_in_zip(zf, filename)
   if zf.in_open_file then
      close_file_in_zip(zf)
      return nil
   end
   local lfh = {}
   zf.local_file_header = lfh
   lfh.last_mod_file_time = 0 -- TODO
   lfh.last_mod_file_date = 0 -- TODO
   lfh.crc32 = 0 -- initial value
   lfh.compressed_size = 0 -- unknown yet
   lfh.uncompressed_size = 0 -- unknown yet
   lfh.file_name_length = #filename
   lfh.extra_field_length = 0
   lfh.file_name = filename:gsub("\\", "/")
   zf.in_open_file = true
   zf.data = {}
   return true
end

--- Write data to the file currently being stored in the zipfile.
-- @param zf handle of the zipfile being written.
-- @param buf string containing data to be written.
-- @return true if succeeded, nil in case of failure.
function write_in_file_in_zip(zf, buf)
   if not zf.in_open_file then
      return nil
   end
   local lfh = zf.local_file_header
   local cbuf = zlib.compress(buf):sub(3, -5)
   lfh.crc32 = zlib.crc32(lfh.crc32, buf)
   lfh.compressed_size = lfh.compressed_size + #cbuf
   lfh.uncompressed_size = lfh.uncompressed_size + #buf
   table.insert(zf.data, cbuf)
   return true
end

--- Complete the writing of a file stored in the zipfile.
-- @param zf handle of the zipfile being written.
-- @return true if succeeded, nil in case of failure.
function write_close_file_in_zip(zf)
   local zh = zf.ziphandle
   
   if not zf.in_open_file then
      return nil
   end

   -- Local file header
   local lfh = zf.local_file_header
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
   for _, cbuf in ipairs(zf.data) do
      zh:write(cbuf)
   end
   
   -- Data descriptor
   zh:write(number_to_bytestring(lfh.crc32, 4))
   zh:write(number_to_bytestring(lfh.compressed_size, 4))
   zh:write(number_to_bytestring(lfh.uncompressed_size, 4))
   
   table.insert(zf.files, lfh)
   zf.in_open_file = false
   
   return true
end

--- Complete the writing of the zipfile.
-- @param zf handle of the zipfile being written.
-- @return true if succeeded, nil in case of failure.
function write_close(zf)
   local zh = zf.ziphandle
   
   local central_directory_offset = zh:seek()
   
   local size_of_central_directory = 0
   -- Central directory structure
   for _, lfh in ipairs(zf.files) do
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
      zh:write(number_to_bytestring(0, 4)) -- external file attributes
      zh:write(number_to_bytestring(lfh.offset, 4)) -- relative offset of local header
      zh:write(lfh.file_name)
      size_of_central_directory = size_of_central_directory + 46 + lfh.file_name_length
   end
   
   -- End of central directory record
   zh:write(number_to_bytestring(0x06054b50, 4)) -- signature
   zh:write(number_to_bytestring(0, 2)) -- number of this disk
   zh:write(number_to_bytestring(0, 2)) -- number of disk with start of central directory
   zh:write(number_to_bytestring(#zf.files, 2)) -- total number of entries in the central dir on this disk
   zh:write(number_to_bytestring(#zf.files, 2)) -- total number of entries in the central dir
   zh:write(number_to_bytestring(size_of_central_directory, 4))
   zh:write(number_to_bytestring(central_directory_offset, 4))
   zh:write(number_to_bytestring(0, 2)) -- zip file comment length
   zh:close()

   return true
end

-- @return boolean or (boolean, string): true on success,
-- false and an error message on failure.
local function add_to_zip(zf, file)
   local fin
   local ok, err = write_open_new_file_in_zip(zf, file)
   if not ok then
      err = "error in opening "..file.." in zipfile"
   else
      fin = io.open(file, "rb")
      if not fin then
         ok = false
         err = "error opening "..file.." for reading"
      end
   end
   while ok do
      local buf = fin:read(size_buf)
      if not buf then
         break
      end
      ok = write_in_file_in_zip(zf, buf)
      if not ok then
         err = "error in writing "..file.." in the zipfile"
      end
   end
   if fin then
      fin:close()
   end
   if ok then
      ok = write_close_file_in_zip(zf)
      if not ok then
         err = "error in writing "..file.." in the zipfile"
      end
   end
   return ok == true, err
end

--- Compress files in a .zip archive.
-- @param zipfile string: pathname of .zip archive to be created.
-- @param ... Filenames to be stored in the archive are given as
-- additional arguments.
-- @return boolean or (boolean, string): true on success,
-- false and an error message on failure.
function zip(zipfile, ...)
   local zf = write_open(filename)
   if not zf then
      return nil, "error opening "..filename
   end

   local ok, err
   for _, file in pairs({...}) do
      if fs.is_dir(file) then
         for _, file in pairs(fs.find(file)) do
            if fs.is_file(file) then
               ok, err = add_to_zip(file)
               if not ok then break end
            end
         end
      else
         ok, err = add_to_zip(file)
         if not ok then break end
      end
   end

   local ok = write_close(zf)
   if not ok then
      return false, "error closing "..filename
   end
   return ok, err
end
