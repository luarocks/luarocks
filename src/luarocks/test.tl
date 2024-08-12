local record test
end

local fetch = require("luarocks.fetch")
local deps = require("luarocks.deps")
local util = require("luarocks.util")

local type r = require("luarocks.core.types.rockspec")
local type Rockspec = r.Rockspec
local type Test = r.Test


local type t = require("luarocks.core.types.testrunner")
local type TestRunner = t.TestRunner

local test_types = {
   "busted",
   "command",
}

local test_modules: {string | TestRunner} = {}

for _, test_type in ipairs(test_types) do
   local mod: TestRunner
   if test_type == "command" then
      mod = require("luarocks.test.command")
   elseif test_type == "busted" then
      mod = require("luarocks.test.busted")
   end
   table.insert(test_modules, mod)
   test_modules[test_type] = mod --!
   test_modules[mod] = test_type
end

local function get_test_type(rockspec: Rockspec): string, string
   if rockspec.test and rockspec.test.type then
      return rockspec.test.type
   end

   for _, test_module in ipairs(test_modules) do
      if test_module.detect_type() then
         return test_modules[test_module]
      end
   end

   return nil, "could not detect test type -- no test suite for " .. rockspec.package .. "?"
end

-- Run test suite as configured in rockspec in the current directory.
function test.run_test_suite(rockspec_arg: string | Rockspec, test_type: string, args, prepare): boolean, string, string
   local rockspec: Rockspec
   if rockspec_arg is string then
      local err, errcode: string, string
      rockspec, err, errcode = fetch.load_rockspec(rockspec_arg)
      if err then
         return nil, err, errcode
      end
   else
      rockspec = rockspec_arg
   end

   if not test_type then
      local err: string
      test_type, err = get_test_type(rockspec, test_type) --!
      if not test_type then
         return nil, err
      end
   end
   assert(test_type) --!

   local all_deps = {
      "dependencies",
      "build_dependencies",
      "test_dependencies",
   }
   for _, dep_kind in ipairs(all_deps) do
      if rockspec[dep_kind] and next(rockspec[dep_kind]) then --! rockspec as {atring: any}
         local _, err, errcode = deps.fulfill_dependencies(rockspec, dep_kind, "all")
         if err then
            return nil, err, errcode
         end
      end
   end

   local pok, test_mod: boolean --! Test type
   if test_type == "command" then
      pok, test_mod = pcall(require, "luarocks.test.command")
      if not pok then
         return nil, "failed loading test execution module luarocks.test.command"
      end
   elseif test_type == "busted" then
      pok, test_mod = pcall(require, "luarocks.test.busted")
      if not pok then
         return nil, "failed loading test execution module luarocks.test.busted"
      end
   end

   if prepare then
      if test_type == "busted" then
         return test_mod.run_tests(rockspec_arg, {"--version"})
      else
         return true
      end
   else
      local flags = rockspec.test and rockspec.test.flags
      if type(flags) == "table" then
         util.variable_substitutions(flags, rockspec.variables)

         -- insert any flags given in test.flags at the front of args
         for i = 1, #flags do
            table.insert(args, i, flags[i])
         end
      end

      return test_mod.run_tests(rockspec.test, args)
   end
end

return test
