local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type

local pack = {}


local queries = require("luarocks.queries")
local path = require("luarocks.path")
local repos = require("luarocks.repos")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")
local search = require("luarocks.search")
local signing = require("luarocks.signing")














function pack.pack_source_rock(rockspec_file)

   local rockspec, errload = fetch.load_rockspec(rockspec_file)
   if errload then
      return nil, "Error loading rockspec: " .. errload
   end
   rockspec_file = rockspec.local_abs_filename

   local name_version = rockspec.name .. "-" .. rockspec.version
   local rock_file = fs.absolute_name(name_version .. ".src.rock")

   local temp_dir, err = fs.make_temp_dir("pack-" .. name_version)
   if not temp_dir then
      return nil, "Failed creating temporary directory: " .. err
   end
   util.schedule_function(fs.delete, temp_dir)

   local source_file, source_dir = fetch.fetch_sources(rockspec, true, temp_dir)
   if not source_file then
      return nil, source_dir
   end
   local ok, errchange = fs.change_dir(source_dir)
   if not ok then return nil, errchange end

   fs.delete(rock_file)
   fs.copy(rockspec_file, source_dir, "read")
   ok, err = fs.zip(rock_file, dir.base_name(rockspec_file), dir.base_name(source_file))
   if not ok then
      return nil, "Failed packing " .. rock_file .. " - " .. err
   end
   fs.pop_dir()

   return rock_file
end

local function copy_back_files(name, version, file_tree, deploy_dir, pack_dir, perms)
   local ok, err = fs.make_dir(pack_dir)
   if not ok then return nil, err end
   for file, sub in pairs(file_tree) do
      local source = dir.path(deploy_dir, file)
      local target = dir.path(pack_dir, file)
      if type(sub) == "table" then
         ok, err = copy_back_files(name, version, sub, source, target)
         if not ok then return nil, err end
      else
         local versioned = path.versioned_name(source, deploy_dir, name, version)
         if fs.exists(versioned) then
            fs.copy(versioned, target, perms)
         else
            fs.copy(source, target, perms)
         end
      end
   end
   return true
end






function pack.pack_installed_rock(query, tree)

   local name, version, repo, repo_url = search.pick_installed_rock(query, tree)
   if not name then
      return nil, version
   end

   local root = path.root_from_rocks_dir(repo_url)
   local prefix = path.install_dir(name, version, root)
   if not fs.exists(prefix) then
      return nil, "'" .. name .. " " .. version .. "' does not seem to be an installed rock."
   end

   local rock_manifest, err = manif.load_rock_manifest(name, version, root)
   if not rock_manifest then return nil, err end

   local name_version = name .. "-" .. version
   local rock_file = fs.absolute_name(name_version .. "." .. cfg.arch .. ".rock")

   local temp_dir = fs.make_temp_dir("pack")
   fs.copy_contents(prefix, temp_dir)

   local ok
   local is_binary = false
   if rock_manifest.lib then
      ok, err = copy_back_files(name, version, (rock_manifest.lib), path.deploy_lib_dir(repo), dir.path(temp_dir, "lib"), "exec")
      if not ok then return nil, "Failed copying back files: " .. err end
      is_binary = true
   end
   if rock_manifest.lua then
      ok, err = copy_back_files(name, version, (rock_manifest.lua), path.deploy_lua_dir(repo), dir.path(temp_dir, "lua"), "read")
      if not ok then return nil, "Failed copying back files: " .. err end
   end

   ok, err = fs.change_dir(temp_dir)
   if not ok then return nil, err end
   if not is_binary and not repos.has_binaries(name, version) then
      rock_file = rock_file:gsub("%." .. cfg.arch:gsub("%-", "%%-") .. "%.", ".all.")
   end
   fs.delete(rock_file)
   ok, err = fs.zip(rock_file, _tl_table_unpack(fs.list_dir()))
   if not ok then
      return nil, "Failed packing " .. rock_file .. " - " .. err
   end
   fs.pop_dir()
   fs.delete(temp_dir)
   return rock_file
end

function pack.report_and_sign_local_file(file, err, sign)
   if err then
      return nil, err
   end
   local sigfile
   if sign then
      sigfile, err = signing.sign_file(file)
      util.printout()
   end
   util.printout("Packed: " .. file)
   if sigfile then
      util.printout("Signature stored in: " .. sigfile)
   end
   if err then
      return nil, err
   end
   return true
end

function pack.pack_binary_rock(name, namespace, version, sign, cmd)








   local temp_dir, err = fs.make_temp_dir("luarocks-build-pack-" .. dir.base_name(name))
   if not temp_dir then
      return nil, "Failed creating temporary directory: " .. err
   end
   util.schedule_function(fs.delete, temp_dir)

   path.use_tree(temp_dir)

   local ret
   ret, err = cmd()
   if not ret then
      return nil, err
   end

   local rname, rversion = path.parse_name(name)
   if not rname then
      rname, rversion = name, version
   end
   local query = queries.new(rname, namespace, rversion)

   local file
   file, err = pack.pack_installed_rock(query, temp_dir)

   return pack.report_and_sign_local_file(file, err, sign)
end

return pack
