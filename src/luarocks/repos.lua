local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type

local repos = { Op = {}, Paths = {} }















local fs = require("luarocks.fs")
local path = require("luarocks.path")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local dir = require("luarocks.dir")
local manif = require("luarocks.manif")
local vers = require("luarocks.core.vers")
































local function get_installed_versions(name)
   assert(not name:match("/"))

   local dirs = fs.list_dir(path.versions_dir(name))
   return (dirs and #dirs > 0) and dirs or nil
end







function repos.is_installed(name, version)
   assert(not name:match("/"))

   return fs.is_dir(path.install_dir(name, version))
end

function repos.recurse_rock_manifest_entry(entry, action)
   if entry == nil then
      return true
   end

   local function do_recurse_rock_manifest_entry(tree, pathname)
      if type(tree) == "string" then
         return action(pathname)
      else
         for file, sub in pairs(tree) do
            local sub_path = pathname and dir.path(pathname, file) or file
            local ok, err = do_recurse_rock_manifest_entry(sub, sub_path)
            if not ok then
               return nil, err
            end
         end
         return true
      end
   end
   return do_recurse_rock_manifest_entry(entry)
end

local function store_package_data(result, rock_manifest, deploy_type)
   if rock_manifest[deploy_type] then
      repos.recurse_rock_manifest_entry(rock_manifest[deploy_type], function(file_path)
         local _, item_name = manif.get_provided_item(deploy_type, file_path)
         result[item_name] = file_path
         return true
      end)
   end
end










function repos.package_modules(name, version)
   assert(not name:match("/"))

   local result = {}
   local rock_manifest = manif.load_rock_manifest(name, version)
   if not rock_manifest then return result end
   store_package_data(result, rock_manifest, "lib")
   store_package_data(result, rock_manifest, "lua")
   return result
end










function repos.package_commands(name, version)
   assert(not name:match("/"))

   local result = {}
   local rock_manifest = manif.load_rock_manifest(name, version)
   if not rock_manifest then return result end
   store_package_data(result, rock_manifest, "bin")
   return result
end







function repos.has_binaries(name, version)
   assert(not name:match("/"))

   local entries = manif.load_rock_manifest(name, version)
   if not entries then
      return false
   end
   local bin = entries["bin"]
   if type(bin) == "table" then
      for bin_name, _md5 in pairs(bin) do

         if fs.is_actual_binary(dir.path(cfg.deploy_bin_dir, bin_name)) then
            return true
         end
      end
   end
   return false
end

function repos.run_hook(rockspec, hook_name)

   local hooks = rockspec.hooks
   if not hooks then
      return true
   end

   if cfg.hooks_enabled == false then
      return nil, "This rockspec contains hooks, which are blocked by the 'hooks_enabled' setting in your LuaRocks configuration."
   end

   if not hooks.substituted_variables then
      util.variable_substitutions(hooks, rockspec.variables)
      hooks.substituted_variables = true
   end
   local hook = (hooks)[hook_name]
   if hook then
      util.printout(hook)
      if not fs.execute(hook) then
         return nil, "Failed running " .. hook_name .. " hook."
      end
   end
   return true
end

function repos.should_wrap_bin_scripts(rockspec)

   if cfg.wrap_bin_scripts then
      return cfg.wrap_bin_scripts
   end
   if rockspec.deploy and rockspec.deploy.wrap_bin_scripts == false then
      return false
   end
   return true
end

local function find_suffixed(file, suffix)
   local filenames = { file }
   if suffix and suffix ~= "" then
      table.insert(filenames, 1, file .. suffix)
   end

   for _, filename in ipairs(filenames) do
      if fs.exists(filename) then
         return filename
      end
   end

   return nil, table.concat(filenames, ", ") .. " not found"
end

local function check_suffix(filename, suffix)
   local suffixed_filename, _err = find_suffixed(filename, suffix)
   if not suffixed_filename then
      return ""
   end
   return suffixed_filename:sub(#filename + 1)
end







local function get_deploy_paths(name, version, deploy_type, file_path, repo)

   repo = repo or cfg.root_dir
   local deploy_dir = (path)["deploy_" .. deploy_type .. "_dir"](repo)
   local non_versioned = dir.path(deploy_dir, file_path)
   local versioned = path.versioned_name(non_versioned, deploy_dir, name, version)
   return { nv = non_versioned, v = versioned }
end

local function check_spot_if_available(name, version, deploy_type, file_path)
   local item_type, item_name = manif.get_provided_item(deploy_type, file_path)
   local cur_name, cur_version = manif.get_current_provider(item_type, item_name)




   if not cur_name and deploy_type == "lua" and item_name:match("%.init$") then
      cur_name, cur_version = manif.get_current_provider(item_type, (item_name:gsub("%.init$", "")))
   end

   if (not cur_name) or
      (name < cur_name) or
      (name == cur_name and (version == cur_version or
      vers.compare_versions(version, cur_version))) then
      return "nv", cur_name, cur_version, item_name
   else

      return "v", cur_name, cur_version, item_name
   end
end

local function backup_existing(should_backup, target)
   if not should_backup then
      fs.delete(target)
      return
   end
   if fs.exists(target) then
      local backup = target
      repeat
         backup = backup .. "~"
      until not fs.exists(backup)

      util.warning(target .. " is not tracked by this installation of LuaRocks. Moving it to " .. backup)
      local move_ok, move_err = os.rename(target, backup)
      if not move_ok then
         return nil, move_err
      end
      return backup
   end
end

local function prepare_op_install()
   local mkdirs = {}
   local rmdirs = {}

   local function memoize_mkdir(d)
      if mkdirs[d] then
         return true
      end
      local ok, err = fs.make_dir(d)
      if not ok then
         return nil, err
      end
      mkdirs[d] = true
      return true
   end

   local function op_install(op)
      local ok, err = memoize_mkdir(dir.dir_name(op.dst))
      if not ok then
         return nil, err
      end

      local backup
      backup, err = backup_existing(op.backup, op.dst)
      if err then
         return nil, err
      end
      if backup then
         op.backup_file = backup
      end

      ok, err = op.fn(op.src, op.dst, op.backup)
      if not ok then
         return nil, err
      end

      rmdirs[dir.dir_name(op.src)] = true
      return true
   end

   local function done_op_install()
      for d, _ in pairs(rmdirs) do
         fs.remove_dir_tree_if_empty(d)
      end
   end

   return op_install, done_op_install
end

local function rollback_install(op)
   fs.delete(op.dst)
   if op.backup_file then
      os.rename(op.backup_file, op.dst)
   end
   fs.remove_dir_tree_if_empty(dir.dir_name(op.dst))
   return true
end

local function op_rename(op)
   if op.suffix then
      local suffix = check_suffix(op.src, op.suffix)
      op.src = op.src .. suffix
      op.dst = op.dst .. suffix
   end

   if fs.exists(op.src) then
      fs.make_dir(dir.dir_name(op.dst))
      fs.delete(op.dst)
      local ok, err = os.rename(op.src, op.dst)
      fs.remove_dir_tree_if_empty(dir.dir_name(op.src))
      return ok, err
   else
      return true
   end
end

local function rollback_rename(op)
   return op_rename({ src = op.dst, dst = op.src })
end

local function prepare_op_delete()
   local deletes = {}
   local rmdirs = {}

   local function done_op_delete()
      for _, f in ipairs(deletes) do
         os.remove(f)
      end

      for d, _ in pairs(rmdirs) do
         fs.remove_dir_tree_if_empty(d)
      end
   end

   local function op_delete(op)
      if op.suffix then
         local suffix = check_suffix(op.name, op.suffix)
         op.name = op.name .. suffix
      end

      table.insert(deletes, op.name)

      rmdirs[dir.dir_name(op.name)] = true
   end

   return op_delete, done_op_delete
end

local function rollback_ops(ops, op_fn, n)
   for i = 1, n do
      op_fn(ops[i])
   end
end


function repos.check_everything_is_installed(name, version, rock_manifest, repo, accept_versioned)
   local missing = {}
   local suffix = cfg.wrapper_suffix or ""
   for _, category in ipairs({ "bin", "lua", "lib" }) do
      if rock_manifest[category] then
         repos.recurse_rock_manifest_entry(rock_manifest[category], function(file_path)
            local paths = get_deploy_paths(name, version, category, file_path, repo)
            if category == "bin" then
               if (fs.exists(paths.nv) or fs.exists(paths.nv .. suffix)) or
                  (accept_versioned and (fs.exists(paths.v) or fs.exists(paths.v .. suffix))) then
                  return true
               end
            else
               if fs.exists(paths.nv) or (accept_versioned and fs.exists(paths.v)) then
                  return true
               end
            end
            table.insert(missing, paths.nv)
            return true
         end)
      end
   end
   if #missing > 0 then
      return nil, "failed deploying files. " ..
      "The following files were not installed:\n" ..
      table.concat(missing, "\n")
   end
   return true
end








function repos.deploy_local_files(name, version, wrap_bin_scripts, deps_mode)
   assert(not name:match("/"))

   local rock_manifest, load_err = manif.load_rock_manifest(name, version)
   if not rock_manifest then return nil, load_err end

   local repo = cfg.root_dir
   local renames = {}
   local installs = {}

   local function install_binary(source, target)
      if wrap_bin_scripts and fs.is_lua(source) then
         return fs.wrap_script(source, target, deps_mode, name, version)
      else
         return fs.copy_binary(source, target)
      end
   end

   local function move_lua(source, target)
      return fs.move(source, target, "read")
   end

   local function move_lib(source, target)
      return fs.move(source, target, "exec")
   end

   if rock_manifest.bin then
      local source_dir = path.bin_dir(name, version)
      repos.recurse_rock_manifest_entry(rock_manifest.bin, function(file_path)
         local source = dir.path(source_dir, file_path)
         local paths = get_deploy_paths(name, version, "bin", file_path, repo)
         local mode, cur_name, cur_version = check_spot_if_available(name, version, "bin", file_path)

         if mode == "nv" and cur_name then
            local cur_paths = get_deploy_paths(cur_name, cur_version, "bin", file_path, repo)
            table.insert(renames, { src = cur_paths.nv, dst = cur_paths.v, suffix = cfg.wrapper_suffix })
         end
         local target = mode == "nv" and paths.nv or paths.v
         local backup = name ~= cur_name or version ~= cur_version
         if wrap_bin_scripts and fs.is_lua(source) then
            target = target .. (cfg.wrapper_suffix or "")
         end
         table.insert(installs, { fn = install_binary, src = source, dst = target, backup = backup })
         return true
      end)
   end

   if rock_manifest.lua then
      local source_dir = path.lua_dir(name, version)
      repos.recurse_rock_manifest_entry(rock_manifest.lua, function(file_path)
         local source = dir.path(source_dir, file_path)
         local paths = get_deploy_paths(name, version, "lua", file_path, repo)
         local mode, cur_name, cur_version = check_spot_if_available(name, version, "lua", file_path)

         if mode == "nv" and cur_name then
            local cur_paths = get_deploy_paths(cur_name, cur_version, "lua", file_path, repo)
            table.insert(renames, { src = cur_paths.nv, dst = cur_paths.v })
            cur_paths = get_deploy_paths(cur_name, cur_version, "lib", file_path:gsub("%.lua$", "." .. cfg.lib_extension), repo)
            table.insert(renames, { src = cur_paths.nv, dst = cur_paths.v })
         end
         local target = mode == "nv" and paths.nv or paths.v
         local backup = name ~= cur_name or version ~= cur_version
         table.insert(installs, { fn = move_lua, src = source, dst = target, backup = backup })
         return true
      end)
   end

   if rock_manifest.lib then
      local source_dir = path.lib_dir(name, version)
      repos.recurse_rock_manifest_entry(rock_manifest.lib, function(file_path)
         local source = dir.path(source_dir, file_path)
         local paths = get_deploy_paths(name, version, "lib", file_path, repo)
         local mode, cur_name, cur_version = check_spot_if_available(name, version, "lib", file_path)

         if mode == "nv" and cur_name then
            local cur_paths = get_deploy_paths(cur_name, cur_version, "lua", file_path:gsub("%.[^.]+$", ".lua"), repo)
            table.insert(renames, { src = cur_paths.nv, dst = cur_paths.v })
            cur_paths = get_deploy_paths(cur_name, cur_version, "lib", file_path, repo)
            table.insert(renames, { src = cur_paths.nv, dst = cur_paths.v })
         end
         local target = mode == "nv" and paths.nv or paths.v
         local backup = name ~= cur_name or version ~= cur_version
         table.insert(installs, { fn = move_lib, src = source, dst = target, backup = backup })
         return true
      end)
   end

   for i, op in ipairs(renames) do
      local ok, err = op_rename(op)
      if not ok then
         rollback_ops(renames, rollback_rename, i - 1)
         return nil, err
      end
   end
   local op_install, done_op_install = prepare_op_install()
   for i, op in ipairs(installs) do
      local ok, err = op_install(op)
      if not ok then
         rollback_ops(installs, rollback_install, i - 1)
         rollback_ops(renames, rollback_rename, #renames)
         return nil, err
      end
   end
   done_op_install()

   local ok, err = repos.check_everything_is_installed(name, version, rock_manifest, repo, true)
   if not ok then
      return nil, err
   end

   return true
end

local function add_to_double_checks(double_checks, name, version)
   double_checks[name] = double_checks[name] or {}
   double_checks[name][version] = true
end

local function double_check_all(double_checks, repo)
   local errs = {}
   for next_name, versions in pairs(double_checks) do
      for next_version in pairs(versions) do
         local rock_manifest
         local ok, err
         rock_manifest, err = manif.load_rock_manifest(next_name, next_version)
         if rock_manifest then
            ok, err = repos.check_everything_is_installed(next_name, next_version, rock_manifest, repo, true)
         end
         if not ok then
            table.insert(errs, err)
         end
      end
   end
   if next(errs) then
      return nil, table.concat(errs, "\n")
   end
   return true
end











function repos.delete_local_version(name, version, _deps_mode, quick)
   assert(not name:match("/"))

   local rock_manifest, load_err = manif.load_rock_manifest(name, version)
   if not rock_manifest then
      if not quick then
         return nil, "rock_manifest file not found for " .. name .. " " .. version .. " - removed entry from the manifest", "remove"
      end
      return nil, load_err, "fail"
   end

   local repo = cfg.root_dir
   local renames = {}
   local deletes = {}

   local double_checks = {}

   if rock_manifest.bin then
      repos.recurse_rock_manifest_entry(rock_manifest.bin, function(file_path)
         local paths = get_deploy_paths(name, version, "bin", file_path, repo)
         local mode, _cur_name, _cur_version, item_name = check_spot_if_available(name, version, "bin", file_path)
         if mode == "v" then
            table.insert(deletes, { name = paths.v, suffix = cfg.wrapper_suffix })
         else
            table.insert(deletes, { name = paths.nv, suffix = cfg.wrapper_suffix })

            local next_name, next_version = manif.get_next_provider("command", item_name)
            if next_name then
               add_to_double_checks(double_checks, next_name, next_version)
               local next_paths = get_deploy_paths(next_name, next_version, "bin", file_path, repo)
               table.insert(renames, { src = next_paths.v, dst = next_paths.nv, suffix = cfg.wrapper_suffix })
            end
         end
         return true
      end)
   end

   if rock_manifest.lua then
      repos.recurse_rock_manifest_entry(rock_manifest.lua, function(file_path)
         local paths = get_deploy_paths(name, version, "lua", file_path, repo)
         local mode, _cur_name, _cur_version, item_name = check_spot_if_available(name, version, "lua", file_path)
         if mode == "v" then
            table.insert(deletes, { name = paths.v })
         else
            table.insert(deletes, { name = paths.nv })

            local next_name, next_version = manif.get_next_provider("module", item_name)
            if next_name then
               add_to_double_checks(double_checks, next_name, next_version)
               local next_lua_paths = get_deploy_paths(next_name, next_version, "lua", file_path, repo)
               table.insert(renames, { src = next_lua_paths.v, dst = next_lua_paths.nv })
               local next_lib_paths = get_deploy_paths(next_name, next_version, "lib", file_path:gsub("%.[^.]+$", ".lua"), repo)
               table.insert(renames, { src = next_lib_paths.v, dst = next_lib_paths.nv })
            end
         end
         return true
      end)
   end

   if rock_manifest.lib then
      repos.recurse_rock_manifest_entry(rock_manifest.lib, function(file_path)
         local paths = get_deploy_paths(name, version, "lib", file_path, repo)
         local mode, _cur_name, _cur_version, item_name = check_spot_if_available(name, version, "lib", file_path)
         if mode == "v" then
            table.insert(deletes, { name = paths.v })
         else
            table.insert(deletes, { name = paths.nv })

            local next_name, next_version = manif.get_next_provider("module", item_name)
            if next_name then
               add_to_double_checks(double_checks, next_name, next_version)
               local next_lua_paths = get_deploy_paths(next_name, next_version, "lua", file_path:gsub("%.[^.]+$", ".lua"), repo)
               table.insert(renames, { src = next_lua_paths.v, dst = next_lua_paths.nv })
               local next_lib_paths = get_deploy_paths(next_name, next_version, "lib", file_path, repo)
               table.insert(renames, { src = next_lib_paths.v, dst = next_lib_paths.nv })
            end
         end
         return true
      end)
   end

   local op_delete, done_op_delete = prepare_op_delete()
   for _, op in ipairs(deletes) do
      op_delete(op)
   end
   done_op_delete()

   if not quick then
      for _, op in ipairs(renames) do
         op_rename(op)
      end

      local ok, err = double_check_all(double_checks, repo)
      if not ok then
         return nil, err, "fail"
      end
   end

   fs.delete(path.install_dir(name, version))
   if not get_installed_versions(name) then
      fs.delete(dir.path(cfg.rocks_dir, name))
   end

   if quick then
      return true, nil, "ok"
   end

   return true, nil, "remove"
end

return repos
