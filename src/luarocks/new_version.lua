
--- Module implementing the LuaRocks "new_version" command.
-- Utility function that writes a new rockspec, updating data from a previous one.
--module("luarocks.new_version", package.seeall)
local new_version = {}
package.loaded["luarocks.new_version"] = new_version

local util = require("luarocks.util")
local download = require("luarocks.download")
local fetch = require("luarocks.fetch")
local persist = require("luarocks.persist")
local fs = require("luarocks.fs")
local type_check = require("luarocks.type_check")

new_version.help_summary = "Auto-write a rockspec for a new version of a rock."
new_version.help_arguments = "{<package>|<rockspec>} [<new_version>] [<new_url>]"
new_version.help = [[
This is a utility function that writes a new rockspec, updating data
from a previous one.

If a package name is given, it downloads the latest rockspec from the
default server. If a rockspec is given, it uses it instead.

If the version number is not given, it only increments the revision
number of the given (or downloaded) rockspec.

If a URL is given, it replaces the one from the old rockspec with the
given URL. If a URL is not given and a new version is given, it tries
to guess the new URL by replacing occurrences of the version number
in the URL or tag. It also tries to download the new URL to determine
the new MD5 checksum.

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

local function check_url_and_update_md5(out_rs, out_name)
   local old_md5 = out_rs.source.md5
   out_rs.source.md5 = nil
   local file, temp_dir = fetch.fetch_url_at_temp_dir(out_rs.source.url, "luarocks-new-version-"..out_name)
   if not file then
      util.printerr("Warning: invalid URL - "..temp_dir)
      return true
   end
   util.printout("File successfully downloaded. Updating MD5 checksum...")
   out_rs.source.md5 = fs.get_md5(file)
   local inferred_dir, found_dir = fetch.find_base_dir(file, temp_dir, out_rs.source.url, out_rs.source.dir)
   if not inferred_dir then
      return nil, found_dir
   end
   if found_dir and found_dir ~= inferred_dir then
      out_rs.source.dir = found_dir
   end
   return out_rs.source.md5 ~= old_md5
end
 
local function update_source_section(out_rs, out_name, url, old_ver, new_ver)
   if url then
      out_rs.source.url = url
      check_url_and_update_md5(out_rs, out_name)
      return true
   end
   if new_ver == old_ver then
      return true
   end
   if not out_rs.source then
      return nil, "'source' table is missing. Invalid rockspec?"
   end
   if out_rs.source.dir then
      try_replace(out_rs.source, "dir", old_ver, new_ver)
   end
   if out_rs.source.file then
      try_replace(out_rs.source, "file", old_ver, new_ver)
   end
   local ok = try_replace(out_rs.source, "url", old_ver, new_ver)
   if ok then
      check_url_and_update_md5(out_rs, out_name)
      return true
   end
   ok = try_replace(out_rs.source, "tag", old_ver, new_ver)
   if not ok then
      ok = check_url_and_update_md5(out_rs, out_name)
      if ok then
         util.printerr("Warning: URL is the same, but MD5 has changed. Old rockspec is broken.")
      end
   end
   if not ok then
      return nil, "Failed to determine the location of the new version."
   end
   return true
end
 
function new_version.run(...)
   local flags, input, version, url = util.parse_flags(...)
   if not input then
      return nil, "Missing arguments: expected program or rockspec. "..util.see_help("new_version")
   end
   assert(type(input) == "string")
   
   local filename = input
   if not input:match(".rockspec$") then
      local err
      filename, err = download.download("rockspec", input)
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
   
   local out_rs = persist.load_into_table(filename)
   local out_name = out_rs.package:lower()
   out_rs.version = new_rockver.."-"..new_rev

   local ok, err = update_source_section(out_rs, out_name, url, old_ver, new_ver)
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
