
--- A pure-Lua implementation of untar (unpacking .tar archives)
module("luarocks.tools.tar", package.seeall)

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local util = require("luarocks.util")

local blocksize = 512

local function get_typeflag(flag)
   if flag == "0" or flag == "\0" then return "file"
   elseif flag == "1" then return "link"
   elseif flag == "2" then return "symlink" -- "reserved" in POSIX, "symlink" in GNU
   elseif flag == "3" then return "character"
   elseif flag == "4" then return "block"
   elseif flag == "5" then return "directory"
   elseif flag == "6" then return "fifo"
   elseif flag == "7" then return "contiguous" -- "reserved" in POSIX, "contiguous" in GNU
   elseif flag == "x" then return "next file"
   elseif flag == "g" then return "global extended header"
   elseif flag == "L" then return "long name"
   elseif flag == "K" then return "long link name"
   end
   return "unknown"
end

local function octal_to_number(octal)
   local exp = 0
   local number = 0
   for i = #octal,1,-1 do
      local digit = tonumber(octal:sub(i,i)) 
      if not digit then break end
      number = number + (digit * 8^exp)
      exp = exp + 1
   end
   return number
end

local function checksum_header(block)
   local sum = 256
   for i = 1,148 do
      sum = sum + block:byte(i)
   end
   for i = 157,500 do
      sum = sum + block:byte(i)
   end
   return sum
end

local function nullterm(s)
   return s:match("^[^%z]*")
end

local function read_header_block(block)
   local header = {}
   header.name = nullterm(block:sub(1,100))
   header.mode = nullterm(block:sub(101,108))
   header.uid = octal_to_number(nullterm(block:sub(109,116)))
   header.gid = octal_to_number(nullterm(block:sub(117,124)))
   header.size = octal_to_number(nullterm(block:sub(125,136)))
   header.mtime = octal_to_number(nullterm(block:sub(137,148)))
   header.chksum = octal_to_number(nullterm(block:sub(149,156)))
   header.typeflag = get_typeflag(block:sub(157,157))
   header.linkname = nullterm(block:sub(158,257))
   header.magic = block:sub(258,263)
   header.version = block:sub(264,265)
   header.uname = nullterm(block:sub(266,297))
   header.gname = nullterm(block:sub(298,329))
   header.devmajor = octal_to_number(nullterm(block:sub(330,337)))
   header.devminor = octal_to_number(nullterm(block:sub(338,345)))
   header.prefix = block:sub(346,500)
   if header.magic ~= "ustar " and header.magic ~= "ustar\0" then
      return false, "Invalid header magic "..header.magic
   end
   if header.version ~= "00" and header.version ~= " \0" then
      return false, "Unknown version "..header.version
   end
   if not checksum_header(block) == header.chksum then
      return false, "Failed header checksum"
   end
   return header
end

function untar(filename, destdir)
   assert(type(filename) == "string")
   assert(type(destdir) == "string")

   local tar_handle = io.open(filename, "r")
   if not tar_handle then return nil, "Error opening file "..filename end
   
   local long_name, long_link_name
   while true do
      local block
      repeat 
         block = tar_handle:read(blocksize)
      until (not block) or checksum_header(block) > 256
      if not block then break end
      local header, err = read_header_block(block)
      if not header then
         util.printerr(err)
      end

      local file_data = tar_handle:read(math.ceil(header.size / blocksize) * blocksize):sub(1,header.size)

      if header.typeflag == "long name" then
         long_name = nullterm(file_data)
      elseif header.typeflag == "long link name" then
         long_link_name = nullterm(file_data)
      else
         if long_name then
            header.name = long_name
            long_name = nil
         end
         if long_link_name then
            header.name = long_link_name
            long_link_name = nil
         end
      end
      local pathname = dir.path(destdir, header.name)
      if header.typeflag == "directory" then
         fs.make_dir(pathname)
      elseif header.typeflag == "file" then
         local dirname = dir.dir_name(pathname)
         if dirname ~= "" then
            fs.make_dir(dirname)
         end
         local file_handle = io.open(pathname, "wb")
         file_handle:write(file_data)
         file_handle:close()
         fs.set_time(pathname, header.mtime)
         if fs.chmod then
            fs.chmod(pathname, header.mode)
         end
      end
      --[[
      for k,v in pairs(header) do
         util.printout("[\""..tostring(k).."\"] = "..(type(v)=="number" and v or "\""..v:gsub("%z", "\\0").."\""))
      end
      util.printout()
      --]]
   end
   return true
end
