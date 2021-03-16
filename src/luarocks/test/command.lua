
local command = {}

local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local cfg = require("luarocks.core.cfg")

local unpack = table.unpack or unpack

function command.detect_type()
   if fs.exists("test.lua") then
      return true
   end
   return false
end

function command.run_tests(test, args)
   if not test then
      test = {
         script = "test.lua"
      }
   end

   if not test.script and not test.command then
      test.script = "test.lua"
   end

   if type(test.flags) == "table" then
      -- insert any flags given in test.flags at the front of args
      for i = 1, #test.flags do
         table.insert(args, i, test.flags[i])
      end
   end

   local ok

   if test.script then
      if not fs.exists(test.script) then
         return nil, "Test script " .. test.script .. " does not exist"
      end
      local lua = fs.Q(dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter))  -- get lua interpreter configured
      ok = fs.execute(lua, test.script, unpack(args))
   elseif test.command then
      ok = fs.execute(test.command, unpack(args))
   end

   if ok then
      return true
   else
      return nil, "tests failed with non-zero exit code"
   end
end

return command
