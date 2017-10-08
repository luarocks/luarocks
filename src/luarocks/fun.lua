
--- A set of basic functional utilities
local fun = {}

function fun.concat_in(xs, ys)
   local rs = xs
   local n = #xs
   for i = 1, #ys do
      rs[i + n] = ys[i]
   end
   return rs
end

function fun.concat(xs, ys)
   return fun.concat_in(fun.concat_in({}, xs), ys)
end

function fun.contains(xs, v)
   for _, x in ipairs(xs) do
      if v == x then
         return true
      end
   end
   return false
end

local function pack(args, offset, ...)
   local n = select("#", ...)
   for i = 1, n do
      args[i + offset] = select(i, ...)
   end
   return args, n + offset
end

local unpack = unpack or table.unpack

function fun.curry(f, ...)
   local as, nas = pack({}, 0, ...)
   return function(...)
      local bs, nbs = pack(as, nas, ...)
      return f(unpack(bs, 1, nbs))
   end
end

function fun.map(xs, f)
   local rs = {}
   for i = 1, #xs do
      rs[i] = f(xs[i])
   end
   return rs
end

function fun.sort_uniq_in(xs, cmp)
   table.sort(xs, cmp)
   -- Remove duplicates from the sorted array.
   local prev = nil
   local i = 1
   while xs[i] do
      local curr = xs[i]
      if curr == prev then
         table.remove(xs, i)
      else
         prev = curr
         i = i + 1
      end
   end
   return xs
end

function fun.string_prepend(a)
   return function(b)
      return a .. b
   end
end

function fun.traverse(t, f)
   return fun.map(t, function(x)
      return type(x) == "table" and fun.traverse(x, f) or f(x)
   end)
end

--- Breadth-first search.
-- Traverses a nested structure using function `trav`,
-- looking for an item that matches a predicate `f`.
-- Function `f` returns a boolean or an element,
-- in which case it is traversed with `trav` as well.
-- This can be used to generate the nested structure lazily
-- (e.g. when scanning a directory tree).
-- @param xs a sequence
-- @param f a function that returns true, false or a function
-- that returns a sequence (`(a) -> (boolean | (()->{a}))`)
-- @return true and the item if found, false if not found.
function fun.bfs(root, trav, pred)
   local q = trav(root)
   local exp = {}
   while true do
      if next(q) then
         local x = table.remove(q)
         local r, v = pred(x)
         if r == true then
            return true, v or x
         elseif r ~= false then
            table.insert(exp, r)
         end
      elseif next(exp) then
         q = trav(table.remove(exp, 1))
      else
         break
      end
   end
   return false
end

return fun
