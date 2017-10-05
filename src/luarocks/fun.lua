
--- A set of basic functional utilities
local fun = {}

function fun.concat(xs, ys)
   local rs = {}
   local n = #xs
   for i = 1, n do
      rs[i] = xs[i]
   end
   for i = 1, #ys do
      rs[i + n] = ys[i]
   end
   return rs
end

function fun.contains(xs, v)
   for _, x in ipairs(xs) do
      if v == x then
         return true
      end
   end
   return false
end

function fun.map(f, xs)
   local rs = {}
   for i = 1, #xs do
      rs[i] = f(xs[i])
   end
   return rs
end

function fun.traverse(f, t)
   return fun.map(function(x)
      return type(x) == "table" and fun.traverse(f, x) or f(x)
   end, t)
end

return fun
