local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string

local dir = {}





local core = require("luarocks.core.dir")

dir.path = core.path
dir.split_url = core.split_url
dir.normalize = core.normalize

local dir_sep = package.config:sub(1, 1)





function dir.base_name(pathname)

   local b
   b = pathname:gsub("[/\\]", "/")
   b = b:gsub("/*$", "")
   b = b:match(".*[/\\]([^/\\]*)")
   b = b or pathname

   return b
end






function dir.dir_name(pathname)

   local d
   d = pathname:gsub("[/\\]", "/")
   d = d:gsub("/*$", "")
   d = d:match("(.*)[/]+[^/]*")
   d = d or ""
   d = d:gsub("/", dir_sep)

   return d
end



function dir.is_basic_protocol(protocol)
   return protocol == "http" or protocol == "https" or protocol == "ftp" or protocol == "file"
end

function dir.deduce_base_dir(url)

   local known_exts = {}
   for _, ext in ipairs({ "zip", "git", "tgz", "tar", "gz", "bz2" }) do
      known_exts[ext] = ""
   end
   local base = dir.base_name(url)
   return (base:gsub("%.([^.]*)$", known_exts):gsub("%.tar", ""))
end

return dir
