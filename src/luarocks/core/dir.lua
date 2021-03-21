
local dir = {}

local require = nil
--------------------------------------------------------------------------------

local function unquote(c)
   local first, last = c:sub(1,1), c:sub(-1)
   if (first == '"' and last == '"') or
      (first == "'" and last == "'") then
      return c:sub(2,-2)
   end
   return c
end

--- Describe a path in a cross-platform way.
-- Use this function to avoid platform-specific directory
-- separators in other modules. Removes trailing slashes from
-- each component given, to avoid repeated separators.
-- Separators inside strings are kept, to handle URLs containing
-- protocols.
-- @param ... strings representing directories
-- @return string: a string with a platform-specific representation
-- of the path.
function dir.path(...)
   local t = {...}
   while t[1] == "" do
      table.remove(t, 1)
   end
   for i, c in ipairs(t) do
      t[i] = unquote(c)
   end
   return (table.concat(t, "/"):gsub("([^:])/+", "%1/"):gsub("^/+", "/"):gsub("/*$", ""))
end

--- Split protocol and path from an URL or local pathname.
-- URLs should be in the "protocol://path" format.
-- For local pathnames, "file" is returned as the protocol.
-- @param url string: an URL or a local pathname.
-- @return string, string: the protocol, and the pathname without the protocol.
function dir.split_url(url)
   assert(type(url) == "string")

   url = unquote(url)
   local protocol, pathname = url:match("^([^:]*)://(.*)")
   if not protocol then
      protocol = "file"
      pathname = url
   end
   return protocol, pathname
end

--- Normalize a url or local path.
-- URLs should be in the "protocol://path" format. System independent
-- forward slashes are used, removing trailing and double slashes
-- @param url string: an URL or a local pathname.
-- @return string: Normalized result.
function dir.normalize(name)
   local protocol, pathname = dir.split_url(name)
   pathname = pathname:gsub("\\", "/"):gsub("(.)/*$", "%1"):gsub("//", "/")
   local pieces = {}
   local drive = ""
   if pathname:match("^.:") then
      drive, pathname = pathname:match("^(.:)(.*)$")
   end
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
   local basename = pathname:match("[^/]+$")
   if basename then
      table.insert(pieces, basename)
   end
   pathname = drive .. table.concat(pieces, "/")
   if protocol ~= "file" then pathname = protocol .."://"..pathname end
   return pathname
end

return dir

