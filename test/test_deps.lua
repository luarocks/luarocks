#!/usr/bin/env lua

deps = require "luarocks.deps"

print(deps.show_dep(deps.parse_dep("lfs 2.1.9pre5"), true))
print(deps.show_dep(deps.parse_dep("cgilua cvs-2"), true))
print(deps.show_dep(deps.parse_dep("foobar 0.0.1beta"), true))
print(deps.show_dep(deps.parse_dep("foobar 0.0.1a"), true))

print(deps.show_dep(deps.parse_dep("foobar 1"), true))
print(deps.show_dep(deps.parse_dep("foobar 2.0"), true))
print(deps.show_dep(deps.parse_dep("foobar 3.5a4"), true))
print(deps.show_dep(deps.parse_dep("foobar 1.1pre2"), true))
print(deps.show_dep(deps.parse_dep("foobar 2.0-beta3"), true))
print(deps.show_dep(deps.parse_dep("foobar 5.3"), true))
print(deps.show_dep(deps.parse_dep("foobar 3.5rc2"), true))
print(deps.show_dep(deps.parse_dep("foobar 4.19p"), true))

print()
comparisons = {
--  first       second      eq     le
   {"Vista",   "XP",       false, true},
   {"XP",      "3.1",       false, true},
   {"1.0",      "1.0",      true,  false},
   {"2.2.10",   "2.2-10",   false, false},
   {"2.2",      "2.2-10",   true,  false},
   {"1.0beta1", "1.0rc3",   false, true},
   {"2.0beta3", "2.0",      false, true},
   {"2.0beta", "2.0beta2",  false, true},
   {"2.0beta4", "2.0beta3", false, false},
   {"2.1alpha1", "2.0beta1", false, false},
   {"1.5p3",    "1.5.1",    false, true},
   {"1.1.3",    "1.1.3a",   false, true},
   {"1.5a100",  "1.5b1",    false, true},
   {"2.0alpha100", "2.0beta1", false, true},
   {"2.0.0beta3", "2.0beta2", false, false},
   {"2.0-1", "2.0-2", false, true},
   {"2.0-2", "2.0-1", false, false},
   --[[
   -- Corner cases I don't wish to handle by now.
   {"2.0.0beta2", "2.0beta2", true, true},
   {"2.0.0beta2", "2.0beta3", false, true},
   ]]
}

local v1, v2

err = false

function result(test, expected)
   if test == expected then
      print(test, "OK")
   else
      print(test, "ERROR", deps.show_version(v1, true), deps.show_version(v2, true))
      err = true
   end
end

for _, c in ipairs(comparisons) do
   v1, v2 = deps.parse_version(c[1]), deps.parse_version(c[2])
   print(c[1].." == "..c[2].." ?")
   result(v1 == v2, c[3])
   print(c[1].." < "..c[2].." ?")
   result(v1 < v2, c[4])
end

if err then os.exit(1) end
