
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

   -- Save the original install command before substitution,
   -- so we can display it with the final deploy paths instead of the staging paths.
   local orig_install_command = build.install_command

   util.variable_substitutions(build as {string: string}, rockspec.variables)

   -- Create display variables that replace LUADIR/LIBDIR/BINDIR with the
   -- actual deploy directories so the printed command shows the final destination.
   local display_vars: {string: string} = {}
   for k, v in pairs(rockspec.variables as {string: string}) do
      display_vars[k] = v
   end
   if cfg.deploy_lua_dir then display_vars.LUADIR = cfg.deploy_lua_dir end
   if cfg.deploy_lib_dir then display_vars.LIBDIR = cfg.deploy_lib_dir end
   if cfg.deploy_bin_dir then display_vars.BINDIR = cfg.deploy_bin_dir end

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
      -- Print with deploy paths for user clarity
      local display: {string: string} = {install_command = orig_install_command}
      util.variable_substitutions(display, display_vars)
      util.printout(display.install_command)
      -- Execute with staging paths (internal mechanism)
      if not fs.execute_env(env, build.install_command) then
         return nil, "Failed installing."
      end
   end
   return true
end

return command
