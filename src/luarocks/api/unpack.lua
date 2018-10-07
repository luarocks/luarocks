local unpack_api = {}

local build = require("luarocks.build")
local dir = require("luarocks.dir")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local search = require("luarocks.search")
local util = require("luarocks.util")

--- Load a rockspec file to the given directory, fetches the source
-- files specified in the rockspec, and unpack them inside the directory.
-- @param rockspec_file string: The URL for a rockspec file.
-- @param dir_name string: The directory where to store and unpack files.
-- @return table or (nil, string): the loaded rockspec table or 
-- nil and an error message.
local function unpack_rockspec(rockspec_file, dir_name)
   assert(type(rockspec_file) == "string")
   assert(type(dir_name) == "string")

   local rockspec, err = fetch.load_rockspec(rockspec_file)
   if not rockspec then
      return nil, "Failed loading rockspec " .. rockspec_file .. ": " .. err
   end

   local ok, err = fs.change_dir(dir_name)
   if not ok then return nil, err end

   local ok, sources_dir = fetch.fetch_sources(rockspec, true, ".")
   if not ok then
      return nil, sources_dir
   end

   ok, err = fs.change_dir(sources_dir)
   if not ok then return nil, err end

   ok, err = build.apply_patches(rockspec)
   fs.pop_dir()
   if not ok then return nil, err end

   return rockspec
end

--- Load a .rock file to the given directory and unpack it inside it.
-- @param rock_file string: The URL for a .rock file.
-- @param dir_name string: The directory where to unpack.
-- @param kind string: the kind of rock file, as in the second-level
-- extension in the rock filename (eg. "src", "all", "linux-x86")
-- @return table or (nil, string): the loaded rockspec table or 
-- nil and an error message.
local function unpack_rock(rock_file, dir_name, kind)
   assert(type(rock_file) == "string")
   assert(type(dir_name) == "string")

   local ok, err, errcode = fetch.fetch_and_unpack_rock(rock_file, dir_name)
   if not ok then
      return nil, "Failed unzipping rock " .. rock_file, errcode
   end

   ok, err = fs.change_dir(dir_name)
   if not ok then return nil, err end

   local rockspec_file = dir_name .. ".rockspec"
   local rockspec, err = fetch.load_rockspec(rockspec_file)
   if not rockspec then
      return nil, "Failed loading rockspec " .. rockspec_file .. ": " .. err
   end

   if kind == "src" then
      if rockspec.source.file then
         local ok, err = fs.unpack_archive(rockspec.source.file)
         if not ok then
            return nil, err
         end

         ok, err = fs.change_dir(rockspec.source.dir)
         if not ok then return nil, err end

         ok, err = build.apply_patches(rockspec)
         fs.pop_dir()
         if not ok then return nil, err end
      end
   end

   return rockspec
end

--- Create a directory and perform the necessary actions so that
-- the sources for the rock and its rockspec are unpacked inside it,
-- laid out properly so that the 'make' command is able to build the module.
-- @param file string: A rockspec or .rock URL.
-- @return boolean or (nil, string): true if successful or nil followed
-- by an error message.
local function run_unpacker(file, force)
   assert(type(file) == "string")
   
   local base_name = dir.base_name(file)
   local dir_name, kind, extension = base_name:match("(.*)%.([^.]+)%.(rock)$")
   if not extension then
      dir_name, extension = base_name:match("(.*)%.(rockspec)$")
      kind = "rockspec"
   end
   if not extension then
      return nil, file .. " does not seem to be a valid filename."
   end

   local exists = fs.exists(dir_name)
   if exists and not force then
      return nil, "Directory " .. dir_name .. " already exists."
   end
   if not exists then
      local ok, err = fs.make_dir(dir_name)
      if not ok then return nil, err end
   end
   local rollback = util.schedule_function(fs.delete, fs.absolute_name(dir_name))

   local rockspec, err
   if extension == "rock" then
      rockspec, err = unpack_rock(file, dir_name, kind)
   elseif extension == "rockspec" then
      rockspec, err = unpack_rockspec(file, dir_name)
   end
   if not rockspec then
      return nil, err
   end
   if kind == "src" or kind == "rockspec" then
      if rockspec.source.dir ~= "." then
         local ok = fs.copy(rockspec.local_abs_filename, rockspec.source.dir, "read")
         if not ok then
            return nil, "Failed copying unpacked rockspec into unpacked source directory."
         end
      end
   end
   util.remove_scheduled_function(rollback)

   if kind == "src" or kind == "rockspec" then
      return kind, nil, dir.path(dir_name, rockspec.source.dir)
   else
      return kind
   end
end

function unpack_api.unpack(ns_name, force)
   local url, err
   if ns_name:match(".*%.rock") or ns_name:match(".*%.rockspec") then
      url = ns_name
   else
      url, err = search.find_src_or_rockspec(ns_name, version)
      if not url then
         return nil, err
      end
   end
   
   return run_unpacker(url, force) 
end

return unpack_api
