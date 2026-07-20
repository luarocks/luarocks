



local command = { CommandBuild = {} }








local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")







function command.run(rockspec, not_install)

   local build = rockspec.build

   util.variable_substitutions(build, rockspec.variables)

   local env = {
      CC = cfg.variables.CC,


   }

   if build.build_command then
      util.printout(build.build_command)
      if not fs.execute_env(env, build.build_command) then
         return nil, "Failed building."
      end
   end
   if build.install_command and not not_install then
      util.printout(build.install_command)
      if not fs.execute_env(env, build.install_command) then
         return nil, "Failed installing."
      end
   end
   return true
end

return command
