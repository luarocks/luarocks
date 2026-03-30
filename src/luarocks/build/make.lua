local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack



local make = { MakeBuild = {} }














local fs = require("luarocks.fs")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")













local function make_pass(make_cmd, pass, target, variables)
   local assignments = {}
   for k, v in pairs(variables) do
      table.insert(assignments, k .. "=" .. v)
   end
   if pass then
      return fs.execute(make_cmd .. " " .. target, _tl_table_unpack(assignments))
   else
      return true
   end
end





function make.run(rockspec, not_install)

   local build = rockspec.build

   if build.build_pass == nil then build.build_pass = true end
   if build.install_pass == nil then build.install_pass = true end
   build.build_variables = build.build_variables or {}
   build.install_variables = build.install_variables or {}
   build.build_target = build.build_target or ""
   build.install_target = build.install_target or "install"
   local makefile = build.makefile or cfg.makefile
   if makefile then

      build.build_target = "-f " .. makefile .. " " .. build.build_target
      build.install_target = "-f " .. makefile .. " " .. build.install_target
   end

   if build.variables then
      for var, val in pairs(build.variables) do
         build.build_variables[var] = val
         build.install_variables[var] = val
      end
   end

   util.warn_if_not_used(build.build_variables, { CFLAGS = true }, "variable %s was not passed in build_variables")
   util.variable_substitutions(build.build_variables, rockspec.variables)
   util.variable_substitutions(build.install_variables, rockspec.variables)

   local auto_variables = { "CC" }

   for _, variable in ipairs(auto_variables) do
      if not build.build_variables[variable] then
         build.build_variables[variable] = rockspec.variables[variable]
      end
      if not build.install_variables[variable] then
         build.install_variables[variable] = rockspec.variables[variable]
      end
   end


   local make_cmd = cfg.make or rockspec.variables.MAKE

   local ok = make_pass(make_cmd, build.build_pass, build.build_target, build.build_variables)
   if not ok then
      return nil, "Failed building."
   end
   if not not_install then
      ok = make_pass(make_cmd, build.install_pass, build.install_target, build.install_variables)
      if not ok then
         return nil, "Failed installing."
      end
   end
   return true
end

return make
