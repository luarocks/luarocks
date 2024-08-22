local record repo_writer
end

local fs = require("luarocks.fs")
local path = require("luarocks.path")
local repos = require("luarocks.repos")
local writer = require("luarocks.manif.writer")

function repo_writer.deploy_files(name: string, version: string, wrap_bin_scripts: boolean, deps_mode: string, namespace: string): boolean, string
   local ok, err: boolean, string

   if not fs.exists(path.rock_manifest_file(name, version)) then
      ok, err = writer.make_rock_manifest(name, version)
      if err then
         return nil, err
      end
   end

   if namespace then
      ok, err = writer.make_namespace_file(name, version, namespace)
      if not ok then
         return nil, err
      end
   end

   ok, err = repos.deploy_local_files(name, version, wrap_bin_scripts, deps_mode)
   if not ok then
      return nil, err
   end

   ok, err = writer.add_to_manifest(name, version, nil, deps_mode)
   return ok, err
end

function repo_writer.delete_version(name: string, version: string, deps_mode: string, quick?: boolean): boolean,  string
   local ok, err, op = repos.delete_local_version(name, version, deps_mode, quick)

   if op == "remove" then
      local rok, rerr = writer.remove_from_manifest(name, version, nil, deps_mode)
      if ok and not rok then
         ok, err = rok, rerr
      end
   end

   return ok, err
end

function repo_writer.refresh_manifest(rocks_dir: string): boolean, string
   return writer.make_manifest(rocks_dir, "one")
end

return repo_writer

