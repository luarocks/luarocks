local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local table = _tl_compat and _tl_compat.table or table; local type = type; local test = {}


local fetch = require("luarocks.fetch")
local deps = require("luarocks.deps")
local util = require("luarocks.util")







local test_types = {
   "busted",
   "command",
}

local test_modules = {}
local typetomod = {}
local modtotype = {}

for _, test_type in ipairs(test_types) do
   local mod
   if test_type == "command" then
      mod = require("luarocks.test.command")
   elseif test_type == "busted" then
      mod = require("luarocks.test.busted")
   end
   table.insert(test_modules, mod)
   typetomod[test_type] = mod
   modtotype[mod] = test_type
end

local function get_test_type(rockspec)
   if rockspec.test and rockspec.test.type then
      return rockspec.test.type
   end

   for _, test_module in ipairs(test_modules) do
      if test_module.detect_type() then
         return modtotype[test_module]
      end
   end

   return nil, "could not detect test type -- no test suite for " .. rockspec.package .. "?"
end


function test.run_test_suite(rockspec_arg, test_type, args, prepare)
   local rockspec
   if type(rockspec_arg) == "string" then
      local err, errcode
      rockspec, err, errcode = fetch.load_rockspec(rockspec_arg)
      if err then
         return nil, err, errcode
      end
   else
      rockspec = rockspec_arg
   end

   if not test_type then
      local err
      test_type, err = get_test_type(rockspec)
      if not test_type then
         return nil, err
      end
   end

   local all_deps = {
      "dependencies",
      "build_dependencies",
      "test_dependencies",
   }
   for _, dep_kind in ipairs(all_deps) do
      if (rockspec)[dep_kind] and next((rockspec)[dep_kind]) ~= nil then
         local _, err, errcode = deps.fulfill_dependencies(rockspec, dep_kind, "all")
         if err then
            return nil, err, errcode
         end
      end
   end

   local pok, test_mod = pcall(require, "luarocks.test." .. test_type)
   if not pok then
      return nil, "failed loading test execution module luarocks.test." .. test_type
   end

   if prepare then
      if test_type == "busted" then
         return test_mod.run_tests(rockspec.test, { "--version" })
      else
         return true
      end
   else
      local flags = rockspec.test and rockspec.test.flags
      if type(flags) == "table" then
         util.variable_substitutions(flags, rockspec.variables)


         for i = 1, #flags do
            table.insert(args, i, flags[i])
         end
      end

      return test_mod.run_tests(rockspec.test, args)
   end
end

return test
