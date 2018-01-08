package = "invalid_patch"
version = "0.1-1"
source = {
   -- any valid URL
   url = "https://raw.github.com/keplerproject/luarocks/master/src/luarocks/build.lua"
}
description = {
   summary = "A rockspec with an invalid patch",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      build = "build.lua"
   },
   patches = {
      ["I_am_an_invalid_patch.patch"] = 
[[
diff -Naur luadoc-3.0.1/src/luadoc/doclet/html.lua luadoc-3.0.1-new/src/luadoc/doclet/html.lua
--- luadoc-3.0.1/src/luadoc/doclet/html.lua2007-12-21 15:50:48.000000000 -0200
+++ luadoc-3.0.1-new/src/luadoc/doclet/html.lua2008-02-28 01:59:53.000000000 -0300
@@ -18,6 +18,7 @@
- gabba gabba gabba
+ gobo gobo gobo
]]   
   }
}
