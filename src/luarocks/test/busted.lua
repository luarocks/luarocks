
local busted = {}

local fs = require("luarocks.fs")

local unpack = table.unpack or unpack

function busted.detect_type()
   if fs.exists(".busted") then
      return true
   end
   return false
end

function busted.run_tests(test, args)
   if not test then
      test = {}
   end
   
   if type(test.flags) == "table" then
      -- insert any flags given in test.flags at the front of args
      for i = 1, #test.flags do
         table.insert(args, i, test.flags[i])
      end
   end
   
   return fs.execute("busted", unpack(args))
end


return busted
