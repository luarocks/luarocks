local dir_sep = package.config:sub(1, 1)

local function P(p)
   return (p:gsub("/", dir_sep))
end

local function dir_path(...)
   return P((table.concat({ ... }, "/"):gsub("\\", "/"):gsub("/+", "/")))
end

local function get_tmp_path()
   local path = os.tmpname()
   if dir_sep == "\\" and not path:find(":") then
      path = dir_path(os.getenv("TEMP"), path)
   end
   os.remove(path)
   return path
end

--- Create a file containing a string.
-- @param pathname string: path to file.
-- @param str string: content of the file.
local function write_file(pathname, str, finally)
   local file = assert(io.open(pathname, "wb"))
   file:write(str)
   file:close()
   if finally then
      finally(function()
         os.remove(pathname)
      end)
   end
end

return {
   P = P,
   dir_path = dir_path,
   get_tmp_path = get_tmp_path,
   write_file = write_file,
}
