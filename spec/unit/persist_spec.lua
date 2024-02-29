local test_env = require("spec.util.test_env")
local testing_paths = test_env.testing_paths

local persist = require("luarocks.persist")

describe("luarocks.persist #unit", function()
   local runner

   lazy_setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

   describe("persist.save_from_table_to_string", function()
      it("simple table", function()
         assert.are.same([[
bar = 1234
foo = "string"
]], persist.save_from_table_to_string({foo = "string", bar = 1234}))
      end)

      it("nested tables", function()
         assert.are.same([[
bar = {
   baz = "string"
}
foo = {
   1, 2, 3, 4
}
]], persist.save_from_table_to_string({foo = {1, 2, 3, 4}, bar = {baz = "string"}}))
      end)

      it("table with a keyword key (#947)", function()
         assert.are.same([[
bar = {
   ["function"] = "foo"
}
]], persist.save_from_table_to_string({bar = {["function"] = "foo"}}))
      end)

      it("strings with quotes", function()
         assert.are.same([[
bar = "a \\backslash?"
foo = "a \"quote\"?"
]], persist.save_from_table_to_string({foo = 'a "quote"?', bar = 'a \\backslash?'}))
      end)

      it("multiline strings", function()
         assert.are.same([===[
bar = [==[
]]
]=]]==]
foo = [[
First line
Second line]]
]===], persist.save_from_table_to_string({foo = "First line\nSecond line", bar = "]]\n]=]"}))
      end)

      it("multiline strings ending with brackets", function()
         assert.are.same([===[
bar = [==[
]]
]=]==]
foo = [=[
First line
Second line [1]]=]
]===], persist.save_from_table_to_string({foo = "First line\nSecond line [1]", bar = "]]\n]="}))
      end)
   end)
end)
