local pok, with_external_dep = pcall(require, "with_external_dep")
if pok then
   print(with_external_dep.foo)
else
   print(100)
end
