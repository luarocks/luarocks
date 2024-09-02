
local record command
end

local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")

local type Test = require("luarocks.core.types.rockspec").Test

function command.detect_type(): boolean
   if fs.exists("test.lua") then
      return true
   end
   return false
end

function command.run_tests(test: Test, args: {string}): boolean, string
   if not test then
      test = {
         script = "test.lua"
      }
   end

   if not test.script and not test.command then
      test.script = "test.lua"
   end

   local ok: boolean

   if test.script then
      local test_script = test.script
      if not test_script is string then
         return nil, "Malformed rockspec: 'script' expects a string"
      end
      if not fs.exists(test.script) then
         return nil, "Test script " .. test.script .. " does not exist"
      end
      local lua = fs.Q(cfg.variables["LUA"])  -- get lua interpreter configured
      ok = fs.execute(lua, test.script, table.unpack(args))
   elseif test.command then
      local test_command = test.command
      if not test_command is string then
         return nil, "Malformed rockspec: 'command' expects a string"
      end
      ok = fs.execute(test.command, table.unpack(args))
   end

   if ok then
      return true
   else
      return nil, "tests failed with non-zero exit code"
   end
end

return command
