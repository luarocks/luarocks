
--- Functions related to fetching and loading local and remote files.
module("luarocks.fetch", package.seeall)

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local type_check = require("luarocks.type_check")
local path = require("luarocks.path")
local deps = require("luarocks.deps")
local persist = require("luarocks.persist")
local util = require("luarocks.util")

--- Fetch a local or remote file.
-- Make a remote or local URL/pathname local, fetching the file if necessary.
-- Other "fetch" and "load" functions use this function to obtain files.
-- If a local pathname is given, it is returned as a result.
-- @param url string: a local pathname or a remote URL.
-- @param filename string or nil: this function attempts to detect the
-- resulting local filename of the remote file as the basename of the URL;
-- if that is not correct (due to a redirection, for example), the local
-- filename can be given explicitly as this second argument.
-- @return string or (nil, string, [string]): the absolute local pathname for the
-- fetched file, or nil and a message in case of errors, followed by
-- an optional error code.
function fetch_url(url, filename)
   assert(type(url) == "string")
   assert(type(filename) == "string" or not filename)

   local protocol, pathname = dir.split_url(url)
   if protocol == "file" then
      return fs.absolute_name(pathname)
   elseif protocol == "http" or protocol == "ftp" or protocol == "https" then
      local ok = fs.download(url)
      if not ok then
         return nil, "Failed downloading "..url, "network"
      end
      return dir.path(fs.current_dir(), filename or dir.base_name(url))
   else
      return nil, "Unsupported protocol "..protocol
   end
end

--- For remote URLs, create a temporary directory and download URL inside it.
-- This temporary directory will be deleted on program termination.
-- For local URLs, just return the local pathname and its directory.
-- @param url string: URL to be downloaded
-- @param tmpname string: name pattern to use for avoiding conflicts
-- when creating temporary directory.
-- @param filename string or nil: local filename of URL to be downloaded,
-- in case it can't be inferred from the URL.
-- @return (string, string) or (nil, string, [string]): absolute local pathname of
-- the fetched file and temporary directory name; or nil and an error message
-- followed by an optional error code
function fetch_url_at_temp_dir(url, tmpname, filename)
   assert(type(url) == "string")
   assert(type(tmpname) == "string")
   assert(type(filename) == "string" or not filename)
   filename = filename or dir.base_name(url)

   local protocol, pathname = dir.split_url(url)
   if protocol == "file" then
      return pathname, dir.dir_name(fs.absolute_name(pathname))
   else
      local temp_dir = fs.make_temp_dir(tmpname)
      if not temp_dir then
         return nil, "Failed creating temporary directory."
      end
      util.schedule_function(fs.delete, temp_dir)
      fs.change_dir(temp_dir)
      local file, err, errcode = fetch_url(url, filename)
      fs.pop_dir()
      if not file then
         return nil, "Error fetching file: "..err, errcode
      end
      return file, temp_dir
   end
end

--- Obtain a rock and unpack it.
-- If a directory is not given, a temporary directory will be created,
-- which will be deleted on program termination.
-- @param rock_file string: URL or filename of the rock.
-- @param dest string or nil: if given, directory will be used as
-- a permanent destination.
-- @return string or (nil, string, [string]): the directory containing the contents
-- of the unpacked rock.
function fetch_and_unpack_rock(rock_file, dest)
   assert(type(rock_file) == "string")
   assert(type(dest) == "string" or not dest)

   local name = dir.base_name(rock_file):match("(.*)%.[^.]*%.rock")
   
   local rock_file, err, errcode = fetch_url_at_temp_dir(rock_file,"luarocks-rock-"..name)
   if not rock_file then
      return nil, "Could not fetch rock file: " .. err, errcode
   end

   rock_file = fs.absolute_name(rock_file)
   local unpack_dir
   if dest then
      unpack_dir = dest
      fs.make_dir(unpack_dir)
   else
      unpack_dir = fs.make_temp_dir(name)
   end
   if not dest then
      util.schedule_function(fs.delete, unpack_dir)
   end
   fs.change_dir(unpack_dir)
   local ok = fs.unzip(rock_file)
   if not ok then
      return nil, "Failed unpacking rock file: " .. rock_file
   end
   fs.pop_dir()
   return unpack_dir
end

--- Back-end function that actually loads the local rockspec.
-- Performs some validation and postprocessing of the rockspec contents.
-- @param file string: The local filename of the rockspec file.
-- @return table or (nil, string): A table representing the rockspec
-- or nil followed by an error message.
function load_local_rockspec(filename)
   assert(type(filename) == "string")
   filename = fs.absolute_name(filename)
   local rockspec, err = persist.load_into_table(filename)
   if not rockspec then
      return nil, "Could not load rockspec file "..filename.." ("..err..")"
   end

   local ok, err = type_check.type_check_rockspec(rockspec)
   if not ok then
      return nil, filename..": "..err
   end
   
   if rockspec.rockspec_format then
      if deps.compare_versions(rockspec.rockspec_format, type_check.rockspec_format) then
         return nil, "Rockspec format "..rockspec.rockspec_format.." is not supported, please upgrade LuaRocks."
      end
   end

   util.platform_overrides(rockspec.build)
   util.platform_overrides(rockspec.dependencies)
   util.platform_overrides(rockspec.external_dependencies)
   util.platform_overrides(rockspec.source)
   util.platform_overrides(rockspec.hooks)

   local basename = dir.base_name(filename)
   if basename == "rockspec" then
      rockspec.name = rockspec.package:lower()
   else
      rockspec.name = basename:match("(.*)-[^-]*-[0-9]*")
      if not rockspec.name then
         return nil, "Expected filename in format 'name-version-revision.rockspec'."
      end
   end

   local protocol, pathname = dir.split_url(rockspec.source.url)
   if protocol == "http" or protocol == "https" or protocol == "ftp" or protocol == "file" then
      rockspec.source.file = rockspec.source.file or dir.base_name(rockspec.source.url)
   end
   rockspec.source.protocol, rockspec.source.pathname = protocol, pathname

   -- Temporary compatibility
   if not rockspec.source.module then
      rockspec.source.module = rockspec.source.cvs_module
      rockspec.source.tag = rockspec.source.cvs_tag
   end

   local name_version = rockspec.package:lower() .. "-" .. rockspec.version
   if basename ~= "rockspec" and basename ~= name_version .. ".rockspec" then
      return nil, "Inconsistency between rockspec filename ("..basename..") and its contents ("..name_version..".rockspec)."
   end

   rockspec.local_filename = filename
   local filebase = rockspec.source.file or rockspec.source.url
   local base = dir.base_name(filebase)
   base = base:gsub("%.[^.]*$", ""):gsub("%.tar$", "")
   rockspec.source.dir = rockspec.source.dir
                      or rockspec.source.module
                      or ((filebase:match(".lua$") or filebase:match(".c$")) and ".")
                      or base
   if rockspec.dependencies then
      for i = 1, #rockspec.dependencies do
         local parsed = deps.parse_dep(rockspec.dependencies[i])
         if not parsed then
            return nil, "Parse error processing dependency '"..rockspec.dependencies[i].."'"
         end
         rockspec.dependencies[i] = parsed
      end
   else
      rockspec.dependencies = {}
   end
   local ok, err = path.configure_paths(rockspec)
   if err then
      return nil, "Error verifying paths: "..err
   end

   return rockspec
end

--- Load a local or remote rockspec into a table.
-- This is the entry point for the LuaRocks tools. 
-- Only the LuaRocks runtime loader should use
-- load_local_rockspec directly.
-- @param filename string: Local or remote filename of a rockspec.
-- @param location string or nil: Where to download. If not given,
-- a temporary dir is created.
-- @return table or (nil, string, [string]): A table representing the rockspec
-- or nil followed by an error message and optional error code.
function load_rockspec(filename, location)
   assert(type(filename) == "string")

   local name
   local basename = dir.base_name(filename)
   if basename == "rockspec" then
      name = "rockspec"
   else
      name = basename:match("(.*)%.rockspec")
      if not name and not basename == "rockspec" then
         return nil, "Filename '"..filename.."' does not look like a rockspec."
      end
   end
   
   local err, errcode
   if location then
      fs.change_dir(location)
      filename, err = fetch_url(filename)
      fs.pop_dir()
   else
      filename, err, errcode = fetch_url_at_temp_dir(filename,"luarocks-rockspec-"..name)
   end
   if not filename then
      return nil, err, errcode
   end

   return load_local_rockspec(filename)
end

--- Download sources for building a rock using the basic URL downloader.
-- @param rockspec table: The rockspec table
-- @param extract boolean: Whether to extract the sources from
-- the fetched source tarball or not.
-- @param dest_dir string or nil: If set, will extract to the given directory.
-- @return (string, string) or (nil, string, [string]): The absolute pathname of
-- the fetched source tarball and the temporary directory created to
-- store it; or nil and an error message and optional error code.
function get_sources(rockspec, extract, dest_dir)
   assert(type(rockspec) == "table")
   assert(type(extract) == "boolean")
   assert(type(dest_dir) == "string" or not dest_dir)

   local url = rockspec.source.url
   local name = rockspec.name.."-"..rockspec.version
   local filename = rockspec.source.file
   local source_file, store_dir, err, errcode
   if dest_dir then
      fs.change_dir(dest_dir)
      source_file, err, errcode = fetch_url(url, filename)
      fs.pop_dir()
      store_dir = dest_dir
   else
      source_file, store_dir, errcode = fetch_url_at_temp_dir(url, "luarocks-source-"..name, filename)
   end
   if not source_file then
      return nil, err or store_dir, errcode
   end
   if rockspec.source.md5 then
      if not fs.check_md5(source_file, rockspec.source.md5) then
         return nil, "MD5 check for "..filename.." has failed."
      end
   end
   if extract then
      fs.change_dir(store_dir)
      fs.unpack_archive(rockspec.source.file)
      if not fs.exists(rockspec.source.dir) then
         return nil, "Directory "..rockspec.source.dir.." not found inside archive "..rockspec.source.file
      end
      fs.pop_dir()
   end
   return source_file, store_dir
end

--- Download sources for building a rock, calling the appropriate protocol method.
-- @param rockspec table: The rockspec table
-- @param extract boolean: When downloading compressed formats, whether to extract
-- the sources from the fetched archive or not.
-- @param dest_dir string or nil: If set, will extract to the given directory.
-- @return (string, string) or (nil, string): The absolute pathname of
-- the fetched source tarball and the temporary directory created to
-- store it; or nil and an error message.
function fetch_sources(rockspec, extract, dest_dir)
   assert(type(rockspec) == "table")
   assert(type(extract) == "boolean")
   assert(type(dest_dir) == "string" or not dest_dir)

   local protocol = rockspec.source.protocol
   local ok, proto
   if protocol == "http" or protocol == "https" or protocol == "ftp" or protocol == "file" then
      proto = require("luarocks.fetch")
   else
      ok, proto = pcall(require, "luarocks.fetch."..protocol)
      if not ok then
         return nil, "Unknown protocol "..protocol
      end
   end
   
   return proto.get_sources(rockspec, extract, dest_dir)
end
