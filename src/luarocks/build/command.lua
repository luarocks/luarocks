--- Build back-end for raw listing of commands in rockspec files.
local command = {}

local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")

--- Driver function for the "command" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors ocurred,
-- nil and an error message otherwise.
function command.run(rockspec)
   assert(rockspec:type() == "rockspec")

   local build = rockspec.build
   
   util.variable_substitutions(build, rockspec.variables)

   local env = {
      CC = cfg.variables.CC,
      --LD = cfg.variables.LD,
      --CFLAGS = cfg.variables.CFLAGS,
   }

   if build.build_command then
      cfg.log("info", build.build_command)
      if not fs.execute_env(env, build.build_command) then
         return nil, "Failed building."
      end
   end
   if build.install_command then
      cfg.log("info", build.install_command)
      if not fs.execute_env(env, build.install_command) then
         return nil, "Failed installing."
      end
   end
   return true
end

return command
