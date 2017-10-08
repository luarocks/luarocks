
--- Generic utilities for handling pathnames.
local dir = {}

local core = require("luarocks.core.dir")

dir.path = core.path
dir.split_url = core.split_url

--- Strip the path off a path+filename.
-- @param pathname string: A path+name, such as "/a/b/c"
-- or "\a\b\c".
-- @return string: The filename without its path, such as "c".
function dir.base_name(pathname)
   assert(type(pathname) == "string")

   local base = pathname:gsub("[/\\]*$", ""):match(".*[/\\]([^/\\]*)")
   return base or pathname
end

--- Strip the name off a path+filename.
-- @param pathname string: A path+name, such as "/a/b/c".
-- @return string: The filename without its path, such as "/a/b".
-- For entries such as "/a/b/", "/a" is returned. If there are
-- no directory separators in input, "" is returned.
function dir.dir_name(pathname)
   assert(type(pathname) == "string")
   return (pathname:gsub("/*$", ""):match("(.*)[/]+[^/]*")) or ""
end

--- Normalize a url or local path.
-- URLs should be in the "protocol://path" format. System independent
-- forward slashes are used, removing trailing and double slashes
-- @param url string: an URL or a local pathname.
-- @return string: Normalized result.
function dir.normalize(name)
   local protocol, pathname = dir.split_url(name)
   pathname = pathname:gsub("\\", "/"):gsub("(.)/*$", "%1"):gsub("//", "/")
   if protocol ~= "file" then pathname = protocol .."://"..pathname end
   return pathname
end

return dir
