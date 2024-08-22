
--- A set of basic functional utilities
local record fun
end

function fun.concat<K>(xs: {K}, ys: {K}): {K}
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

function fun.contains<K>(xs: {K}, v: K): boolean
   for _, x in ipairs(xs) do
      if v == x then
         return true
      end
   end
   return false
end

function fun.map<K, V>(xs: {K}, f: function(K): V): {V}
   local rs = {}
   for i = 1, #xs do
      rs[i] = f(xs[i])
   end
   return rs
end

function fun.filter<K>(xs: {K}, f: function): {K}
   local rs = {}
   for i = 1, #xs do
      local v = xs[i]
      if f(v) then
         rs[#rs+1] = v
      end
   end
   return rs
end

function fun.reverse_in<K>(t: {K}): {K}
   for i = 1, math.floor(#t/2) do
      local m, n = i, #t - i + 1
      local a, b = t[m], t[n]
      t[m] = b
      t[n] = a
   end
   return t
end

function fun.sort_in<K>(t: {K}, f: table.SortFunction<K>): {K}
   table.sort(t, f)
   return t
end

function fun.flip<K, V, S>(f: function(K, V): S): function(V, K): S
   return function(a: V, b: K): S
      return f(b, a)
   end
end

function fun.find<X, R>(xs: function():(X) | {X} , f: function(X):(R) ): R
   if xs is {X} then
      for _, x in ipairs(xs) do
         local r = f(x)
         if r then
            return r
         end
      end
   else
      for x in xs do
         local r = f(x)
         if r then
            return r
         end
      end
   end
end


function fun.partial<K>(f: (function(...: any): K), ...: any): (function(...: any): K)
   local n = select("#", ...)
   if n == 1 then
      local a = ...
      return function(...): K
         return f(a, ...)
      end
   elseif n == 2 then
      local a, b = ...
      return function(...): K
         return f(a, b, ...)
      end
   else
      local pargs = { n = n, ... }
      return function(...): K
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

function fun.memoize<A, B, C>(fn: (function(A):B, C)): (function(A):B, C)
   local memory: {A: B} = setmetatable({}, { __mode = "k" })
   local errors: {A: C} = setmetatable({}, { __mode = "k" })
   local NIL: B = {} as B
   return function(a: A): B, C
      if memory[a] then
         if memory[a] == NIL then
            return nil, errors[a]
         end
         return memory[a]
      end
      local ret1, ret2 = fn(a)
      if ret1 then
         memory[a] = ret1
      else
         memory[a] = NIL
         errors[a] = ret2
      end
      return ret1, ret2
   end
end

return fun