local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type

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
         rs[#rs + 1] = v
      end
   end
   return rs
end

function fun.reverse_in(t)
   for i = 1, math.floor(#t / 2) do
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

function fun.find(xs, f)
   if type(xs) == "table" then
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
            args[i + n] = fargs[i]
         end
         return f(_tl_table_unpack(args, 1, n + m))
      end
   end
end

function fun.memoize(fn)
   local memory = setmetatable({}, { __mode = "k" })
   local errors = setmetatable({}, { __mode = "k" })
   local NIL = {}
   return function(a)
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
