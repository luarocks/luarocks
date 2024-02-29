local test_env = require("spec.util.test_env")
local testing_paths = test_env.testing_paths

local fun = require("luarocks.fun")

describe("luarocks.fun #unit", function()
   local runner

   lazy_setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

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

   describe("fun.filter", function()
      it("filters the elements in the given table and returns the result in a new table", function()
         local t

         t = {1, 2, "a", "b", 3}
         assert.same(fun.filter(t, function(x) return type(x) == "number" end), {1, 2, 3})
         t = {2, 4, 7, 8}
         assert.same(fun.filter(t, function(x) return x % 2 == 0 end), {2, 4, 8})
      end)
   end)

   describe("fun.reverse_in", function()
      it("reverses the elements in the given table and returns the result in a new table", function()
         local t

         t = {1, 2, 3, 4}
         assert.same(fun.reverse_in(t), {4, 3, 2, 1})
         t = {"a", "b", "c"}
         assert.same(fun.reverse_in(t), {"c", "b", "a"})
      end)
   end)

   describe("fun.sort_in", function()
      it("sorts the elements in the given table and returns the result in a new table", function()
         local t

         t = {4, 2, 3, 1}
         assert.same(fun.sort_in(t), {1, 2, 3, 4})
         t = {"d", "a", "c", "b"}
         assert.same(fun.sort_in(t), {"a", "b", "c", "d"})
      end)
   end)

   describe("fun.flip", function()
      it("returns a function behaving as the one given in the argument but with the arguments interchanged", function()
         local a, b = fun.flip(function(a, b) return a, b end)(5, 6)
         assert.same(a, 6)
         assert.same(b, 5)
      end)
   end)

   describe("fun.partial", function()
      it("partially applies the given arguments to the given function and returns it", function()
         local addOne = fun.partial(function(x, y) return x + y end, 1)
         assert.same(addOne(1), 2)
         assert.same(addOne(2), 3)

         local addTwo = fun.partial(function(x, y, z) return x + y + z end, 1, 1)
         assert.same(addTwo(1), 3)
         assert.same(addTwo(2), 4)

         local addThree = fun.partial(function(x, y, z, t, u) return x + y + z + t + u end, 1, 1, 1)
         assert.same(addThree(1, 1), 5)
         assert.same(addThree(1, 2), 6)
      end)
   end)
end)
