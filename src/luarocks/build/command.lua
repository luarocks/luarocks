
--- Build back-end for raw listing of commands in rockspec files.
module("luarocks.build.command", package.seeall)

local fs = require("luarocks.fs")
local path = require("luarocks.path")
local util = require("luarocks.util")
local manif = require("luarocks.manif")
local cfg = require("luarocks.cfg")
local dir = require("luarocks.dir")

--- Driver function for the "command" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors ocurred,
-- nil and an error message otherwise.
function run(rockspec)
   assert(type(rockspec) == "table")

   local build, name, version = rockspec.build, rockspec.name, rockspec.version

   util.variable_substitutions(build, rockspec.variables)

   if build.build_command then
      util.printout(build.build_command)
      if not fs.execute(build.build_command) then
         return nil, "Failed building."
      end
   end

   local dirs = {
      lua = { dir=cfg.deploy_lua_dir, rock=path.lua_dir(name, version), },
      lib = { dir=cfg.deploy_lib_dir, rock=path.lib_dir(name, version), },
      bin = { dir=cfg.deploy_bin_dir, rock=path.bin_dir(name, version), },
   }
   for d_type, d_data in pairs(dirs) do
      d_data.list= {}
      for _, f in pairs(fs.find(d_data.dir)) do
        if not fs.is_dir(dir.path(d_data.dir, f)) then
          d_data.list[f]= true
        end
      end
   end

   if build.install_command then
      util.printout(build.install_command)
      if not fs.execute(build.install_command) then
         return nil, "Failed installing."
      end
   end

   for d_type, d_data in pairs(dirs) do
      for _, f in pairs(fs.find(d_data.dir)) do
        if not fs.is_dir(dir.path(d_data.dir, f)) then
          if not d_data.list[f] then
            local src = dir.path(d_data.dir, f)
            local dest = dir.path(dirs[d_type]["rock"], f)
            fs.make_dir(dir.dir_name(dest))
            fs.move(src, dest)
          end
        end
      end
   end

   return true
end
