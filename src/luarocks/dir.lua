
module("luarocks.dir", package.seeall)

separator = "/"

--- Strip the path off a path+filename.
-- @param pathname string: A path+name, such as "/a/b/c"
-- or "\a\b\c".
-- @return string: The filename without its path, such as "c".
function base_name(pathname)
   assert(type(pathname) == "string")

   local base = pathname:match(".*[/\\]([^/\\]*)")
   return base or pathname
end

--- Strip the name off a path+filename.
-- @param pathname string: A path+name, such as "/a/b/c".
-- @return string: The filename without its path, such as "/a/b/".
-- For entries such as "/a/b/", "/a/" is returned. If there are
-- no directory separators in input, "" is returned.
function dir_name(pathname)
   assert(type(pathname) == "string")

   return (pathname:gsub("/*$", ""):match("(.*/)[^/]*")) or ""
end

--- Describe a path in a cross-platform way.
-- Use this function to avoid platform-specific directory
-- separators in other modules. If the first item contains a 
-- protocol descriptor (e.g. "http:"), paths are always constituted
-- with forward slashes.
-- @param ... strings representing directories
-- @return string: a string with a platform-specific representation
-- of the path.
function path(...)
   local items = {...}
   local i = 1
   while items[i] do
      if items[i] == "" then
         table.remove(items, i)
      else
         i = i + 1
      end
   end
   return table.concat(items, "/")
end
