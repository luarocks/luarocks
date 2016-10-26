
--- Module implementing the LuaRocks "new_version" command.
-- Utility function that writes a new rockspec, updating data from a previous one.
local new_version = {}

local util = require("luarocks.util")
local download = require("luarocks.download")
local fetch = require("luarocks.fetch")
local persist = require("luarocks.persist")
local fs = require("luarocks.fs")
local type_check = require("luarocks.type_check")

util.add_run_function(new_version)
new_version.help_summary = "Auto-write a rockspec for a new version of a rock."
new_version.help_arguments = "[--tag=<tag>] [<package>|<rockspec>] [<new_version>] [<new_url>]"
new_version.help = [[
This is a utility function that writes a new rockspec, updating data
from a previous one.

If a package name is given, it downloads the latest rockspec from the
default server. If a rockspec is given, it uses it instead. If no argument
is given, it looks for a rockspec same way 'luarocks make' does.

If the version number is not given and tag is passed using --tag,
it is used as the version, with 'v' removed from beginning.
Otherwise, it only increments the revision number of the given
(or downloaded) rockspec.

If a URL is given, it replaces the one from the old rockspec with the
given URL. If a URL is not given and a new version is given, it tries
to guess the new URL by replacing occurrences of the version number
in the URL or tag. It also tries to download the new URL to determine
the new MD5 checksum.

If a tag is given, it replaces the one from the old rockspec. If there is
an old tag but no new one passed, it is guessed in the same way URL is.

WARNING: it writes the new rockspec to the current directory,
overwriting the file if it already exists.
]]

local function try_replace(tbl, field, old, new)
   if not tbl[field] then
      return false
   end
   local old_field = tbl[field]
   local new_field = tbl[field]:gsub(old, new)
   if new_field ~= old_field then
      util.printout("Guessing new '"..field.."' field as "..new_field)
      tbl[field] = new_field
      return true      
   end
   return false
end

-- Try to download source file using URL from a rockspec.
-- If it specified MD5, update it.
-- @return (true, false) if MD5 was not specified or it stayed same,
-- (true, true) if MD5 changed, (nil, string) on error.
local function check_url_and_update_md5(out_rs)
   local file, temp_dir = fetch.fetch_url_at_temp_dir(out_rs.source.url, "luarocks-new-version-"..out_rs.package)
   if not file then
      util.printerr("Warning: invalid URL - "..temp_dir)
      return true, false
   end

   local inferred_dir, found_dir = fetch.find_base_dir(file, temp_dir, out_rs.source.url, out_rs.source.dir)
   if not inferred_dir then
      return nil, found_dir
   end

   if found_dir and found_dir ~= inferred_dir then
      out_rs.source.dir = found_dir
   end

   if file then
      if out_rs.source.md5 then
         util.printout("File successfully downloaded. Updating MD5 checksum...")
         local new_md5, err = fs.get_md5(file)
         if not new_md5 then
            return nil, err
         end
         local old_md5 = out_rs.source.md5
         out_rs.source.md5 = new_md5
         return true, new_md5 ~= old_md5
      else
         util.printout("File successfully downloaded.")
         return true, false
      end
   end
end
 
local function update_source_section(out_rs, url, tag, old_ver, new_ver)
   if tag then
      out_rs.source.tag = tag
   end
   if url then
      out_rs.source.url = url
      return check_url_and_update_md5(out_rs)
   end
   if new_ver == old_ver then
      return true
   end
   if out_rs.source.dir then
      try_replace(out_rs.source, "dir", old_ver, new_ver)
   end
   if out_rs.source.file then
      try_replace(out_rs.source, "file", old_ver, new_ver)
   end
   if try_replace(out_rs.source, "url", old_ver, new_ver) then
      return check_url_and_update_md5(out_rs)
   end
   if tag or try_replace(out_rs.source, "tag", old_ver, new_ver) then
      return true
   end
   -- Couldn't replace anything significant, use the old URL.
   local ok, md5_changed = check_url_and_update_md5(out_rs)
   if not ok then
      return nil, md5_changed
   end
   if md5_changed then
      util.printerr("Warning: URL is the same, but MD5 has changed. Old rockspec is broken.")
   end
   return true
end
 
function new_version.command(flags, input, version, url)
   if not input then
      local err
      input, err = util.get_default_rockspec()
      if not input then
         return nil, err
      end
   end
   assert(type(input) == "string")
   
   local filename, err
   if input:match("rockspec$") then
      filename, err = fetch.fetch_url(input)
      if not filename then
         return nil, err
      end
   else
      filename, err = download.download("rockspec", input:lower())
      if not filename then
         return nil, err
      end
   end

   local valid_rs, err = fetch.load_rockspec(filename)
   if not valid_rs then
      return nil, err
   end

   local old_ver, old_rev = valid_rs.version:match("(.*)%-(%d+)$")
   local new_ver, new_rev

   if flags.tag and not version then
      version = flags.tag:gsub("^v", "")
   end
   
   if version then
      new_ver, new_rev = version:match("(.*)%-(%d+)$")
      new_rev = tonumber(new_rev)
      if not new_rev then
         new_ver = version
         new_rev = 1
      end
   else
      new_ver = old_ver
      new_rev = tonumber(old_rev) + 1
   end
   local new_rockver = new_ver:gsub("-", "")
   
   local out_rs, err = persist.load_into_table(filename)
   local out_name = out_rs.package:lower()
   out_rs.version = new_rockver.."-"..new_rev

   local ok, err = update_source_section(out_rs, url, flags.tag, old_ver, new_ver)
   if not ok then return nil, err end

   if out_rs.build and out_rs.build.type == "module" then
      out_rs.build.type = "builtin"
   end
   
   local out_filename = out_name.."-"..new_rockver.."-"..new_rev..".rockspec"
   
   persist.save_from_table(out_filename, out_rs, type_check.rockspec_order)
   
   util.printout("Wrote "..out_filename)

   local valid_out_rs, err = fetch.load_local_rockspec(out_filename)
   if not valid_out_rs then
      return nil, "Failed loading generated rockspec: "..err
   end
   
   return true
end

return new_version
