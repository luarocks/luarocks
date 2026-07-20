



local command = { CommandBuild = {} }








local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")







function command.run(rockspec, not_install)

   local build = rockspec.build

   -- Save the original install command before substitution,
   -- so we can display it with the final deploy paths instead of the staging paths.
   local orig_install_command = build.install_command

   util.variable_substitutions(build, rockspec.variables)

   -- Create display variables that replace LUADIR/LIBDIR/BINDIR with the
   -- actual deploy directories so the printed command shows the final destination.
   local display_vars = {}
   for k, v in pairs(rockspec.variables) do
      display_vars[k] = v
   end
   if cfg.deploy_lua_dir then display_vars.LUADIR = cfg.deploy_lua_dir end
   if cfg.deploy_lib_dir then display_vars.LIBDIR = cfg.deploy_lib_dir end
   if cfg.deploy_bin_dir then display_vars.BINDIR = cfg.deploy_bin_dir end

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
      -- Print with deploy paths for user clarity
      local display = {install_command = orig_install_command}
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
