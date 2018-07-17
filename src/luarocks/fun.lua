
--- A set of basic functional utilities
local fun = {}

local unpack = table.unpack or unpack

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

function fun.map(xs, f)
   local rs = {}
   for i = 1, #xs do
      rs[i] = f(xs[i])
   end
   return rs
end

function fun.filter(xs, f)
   local rs = {}
   for i = 1, #xs do
      local v = xs[i]
      if f(v) then
         rs[#rs+1] = v
      end
   end
   return rs
end

function fun.traverse(t, f)
   return fun.map(t, function(x)
      return type(x) == "table" and fun.traverse(x, f) or f(x)
   end)
end

function fun.reverse_in(t)
   for i = 1, math.floor(#t/2) do
      local m, n = i, #t - i + 1
      local a, b = t[m], t[n]
      t[m] = b
      t[n] = a
   end
   return t
end

function fun.sort_in(t, f)
   table.sort(t, f)
   return t
end

function fun.flip(f)
   return function(a, b)
      return f(b, a)
   end
end

function fun.partial(f, ...)
   local n = select("#", ...)
   if n == 1 then
      local a = ...
      return function(...)
         return f(a, ...)
      end
   elseif n == 2 then
      local a, b = ...
      return function(...)
         return f(a, b, ...)
      end
   else
      local pargs = { n = n, ... }
      return function(...)
         local m = select("#", ...)
         local fargs = { ... }
         local args = {}
         for i = 1, n do
            args[i] = pargs[i]
         end
         for i = 1, m do
            args[i+n] = fargs[i]
         end
         return f(table.unpack(args, 1, n+m))
      end
   end
end

return fun
