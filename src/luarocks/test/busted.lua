local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack
local busted = {}


local fs = require("luarocks.fs")
local deps = require("luarocks.deps")
local path = require("luarocks.path")
local dir = require("luarocks.dir")
local queries = require("luarocks.queries")



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

   local ok, bustedver, where = deps.fulfill_dependency(queries.new("busted"), nil, nil, nil, "test_dependencies")
   if not ok then
      return nil, bustedver
   end

   local busted_exe
   if test.busted_executable then
      busted_exe = test.busted_executable
   else
      busted_exe = dir.path(path.root_dir(where), "bin", "busted")


      local busted_bat = dir.path(path.root_dir(where), "bin", "busted.bat")

      if not fs.exists(busted_exe) and not fs.exists(busted_bat) then
         return nil, "'busted' executable failed to be installed"
      end
   end

   local err
   ok, err = fs.execute(busted_exe, _tl_table_unpack(args))
   if ok then
      return true
   else
      return nil, err or "test suite failed."
   end
end


return busted
