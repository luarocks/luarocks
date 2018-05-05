local test_env = require("spec.util.test_env")
local fun = require("luarocks.fun")

test_env.unload_luarocks()

describe("LuaRocks fun tests", function()
   describe("fun.concat", function()
      it("returns the concatenation of the two tables given as arguments", function()
         local t1, t2

         t1 = {1, 2, 3}
         t2 = {4, 5, 6}
         assert.same(fun.concat(t1, t2), {1, 2, 3, 4, 5, 6})
         assert.same(fun.concat(t2, t1), {4, 5, 6, 1, 2, 3})
         t1 = {1, 2, 3}
         t2 = {}
         assert.same(fun.concat(t1, t2), {1, 2, 3})
         assert.same(fun.concat(t2, t1), {1, 2, 3})
         t1 = {}
         t2 = {}
         assert.same(fun.concat(t1, t2), {})
      end)
   end)

   describe("fun.contains", function()
      it("checks whether a table contains a given value", function()
         local t

         t = {1, 2, 3}
         assert.truthy(fun.contains(t, 1))
         assert.falsy(fun.contains(t, 4))
         t = {}
         assert.falsy(fun.contains(t, 1))
      end)
   end)

   local addOne = function(x) return x + 1 end

   describe("fun.map", function()
      it("applies a function to each element in the given table and returns the results in a new table", function()
         local t

         t = {1, 2, 3}
         assert.same(fun.map(t, addOne), {2, 3, 4})
         t = {}
         assert.same(fun.map(t, addOne), {})
      end)
   end)

   describe("fun.traverse", function()
      it("recursively applies a function to each element in a given table and returns the results in a new table", function()
         local t

         t = {1, 2, {3, 4, {5, 6}}}
         assert.same(fun.traverse(t, addOne), {2, 3, {4, 5, {6, 7}}})
         t = {1, 2, {}, {1, {}, 2}}
         assert.same(fun.traverse(t, addOne), {2, 3, {}, {2, {}, 3}})
      end)
   end)
end)
