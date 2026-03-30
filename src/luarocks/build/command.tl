
local type Build = require("luarocks.core.types.build").Build

--- Build back-end for raw listing of commands in rockspec files.
local record command
   record CommandBuild
      is Build where self.type == "command"

      build_command: string
      install_command: string
   end
end

local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")

local type Rockspec = require("luarocks.core.types.rockspec").Rockspec

--- Driver function for the "command" build back-end.
-- @param rockspec table: the loaded rockspec.
-- @return boolean or (nil, string): true if no errors occurred,
-- nil and an error message otherwise.
function command.run(rockspec: Rockspec, not_install: boolean): boolean, string, string

   local build = rockspec.build as command.CommandBuild

   util.variable_substitutions(build as {string: string}, rockspec.variables)

   local env: {string: string} = {
      CC = cfg.variables.CC,
      --LD = cfg.variables.LD,
      --CFLAGS = cfg.variables.CFLAGS,
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
