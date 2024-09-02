local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string


local unpack = {}


local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local util = require("luarocks.util")
local build = require("luarocks.build")
local dir = require("luarocks.dir")
local search = require("luarocks.search")







function unpack.add_to_parser(parser)
   local cmd = parser:command("unpack", [[
Unpacks the contents of a rock in a newly created directory.
Argument may be a rock file, or the name of a rock in a rocks server.
In the latter case, the rock version may be given as a second argument.]],
   util.see_also()):
   summary("Unpack the contents of a rock.")

   cmd:argument("rock", "A rock file or the name of a rock."):
   action(util.namespaced_name_action)
   cmd:argument("version", "Rock version."):
   args("?")

   cmd:flag("--force", "Unpack files even if the output directory already exists.")
   cmd:flag("--check-lua-versions", "If the rock can't be found, check repository " ..
   "and report if it is available for another Lua version.")
end







local function unpack_rockspec(rockspec_file, dir_name)

   local rockspec, err = fetch.load_rockspec(rockspec_file)
   if not rockspec then
      return nil, "Failed loading rockspec " .. rockspec_file .. ": " .. err
   end
   local ok
   ok, err = fs.change_dir(dir_name)
   if not ok then return nil, err end
   local filename, sources_dir = fetch.fetch_sources(rockspec, true, ".")
   if not filename then
      return nil, sources_dir
   end
   ok, err = fs.change_dir(sources_dir)
   if not ok then return nil, err end
   ok, err = build.apply_patches(rockspec)
   fs.pop_dir()
   if not ok then return nil, err end
   return rockspec
end








local function unpack_rock(rock_file, dir_name, kind)

   local ok, filename, err, errcode
   filename, err, errcode = fetch.fetch_and_unpack_rock(rock_file, dir_name)
   if not filename then
      return nil, err, errcode
   end
   ok, err = fs.change_dir(dir_name)
   if not ok then return nil, err end
   local rockspec_file = dir_name .. ".rockspec"

   local rockspec
   rockspec, err = fetch.load_rockspec(rockspec_file)
   if not rockspec then
      return nil, "Failed loading rockspec " .. rockspec_file .. ": " .. err
   end

   if kind == "src" then
      if rockspec.source.file then
         ok, err = fs.unpack_archive(rockspec.source.file)
         if not ok then return nil, err end
         ok, err = fetch.find_rockspec_source_dir(rockspec, ".")
         if not ok then return nil, err end
         ok, err = fs.change_dir(rockspec.source.dir)
         if not ok then return nil, err end
         ok, err = build.apply_patches(rockspec)
         fs.pop_dir()
         if not ok then return nil, err end
      end
   end
   return rockspec
end







local function run_unpacker(file, force)

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
      fetch.find_rockspec_source_dir(rockspec, ".")
      if rockspec.source.dir ~= "." then
         local ok = fs.copy(rockspec.local_abs_filename, rockspec.source.dir, "read")
         if not ok then
            return nil, "Failed copying unpacked rockspec into unpacked source directory."
         end
      end
      util.printout()
      util.printout("Done. You may now enter directory ")
      util.printout(dir.path(dir_name, rockspec.source.dir))
      util.printout("and type 'luarocks make' to build.")
   end
   util.remove_scheduled_function(rollback)
   return true
end




function unpack.command(args)
   local url, err
   if args.rock:match(".*%.rock") or args.rock:match(".*%.rockspec") then
      url = args.rock
   else
      url, err = search.find_src_or_rockspec(args.rock, args.namespace, args.version, args.check_lua_versions)
      if not url then
         return nil, err
      end
   end

   return run_unpacker(url, args.force)
end

return unpack
