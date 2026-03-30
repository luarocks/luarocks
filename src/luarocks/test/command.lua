local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type
local command = {}


local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")



function command.detect_type()
   if fs.exists("test.lua") then
      return true
   end
   return false
end

function command.run_tests(test, args)
   if not test then
      test = {
         script = "test.lua",
      }
   end

   if not test.script and not test.command then
      test.script = "test.lua"
   end

   local ok

   if test.script then
      local test_script = test.script
      if not (type(test_script) == "string") then
         return nil, "Malformed rockspec: 'script' expects a string"
      end
      if not fs.exists(test.script) then
         return nil, "Test script " .. test.script .. " does not exist"
      end
      local lua = fs.Q(cfg.variables["LUA"])
      ok = fs.execute(lua, test.script, _tl_table_unpack(args))
   elseif test.command then
      local test_command = test.command
      if not (type(test_command) == "string") then
         return nil, "Malformed rockspec: 'command' expects a string"
      end
      ok = fs.execute(test.command, _tl_table_unpack(args))
   end

   if ok then
      return true
   else
      return nil, "tests failed with non-zero exit code"
   end
end

return command
