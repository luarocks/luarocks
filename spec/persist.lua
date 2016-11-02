local test_env = require("test/test_environment")

test_env.unload_luarocks()
local persist = require("luarocks.persist")

describe("Luarocks persist test #whitebox #w_persist", function()
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
