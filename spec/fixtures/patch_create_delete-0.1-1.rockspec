rockspec_format = "3.0"
package = "patch_create_delete"
version = "0.1-1"
source = {
   -- any valid URL
   url = "git://github.com/luarocks/luarocks"
}
description = {
   summary = "A rockspec with a patch that creates and deletes files",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["luarocks.loader"] = "src/luarocks/loader.lua"
   },
   patches = {
      ["create_delete.patch"] = 
[[
diff -Naur luarocks/spec/fixtures/patch_create_delete/a_file.txt luarocks-patch/spec/fixtures/patch_create_delete/a_file.txt
--- luarocks/spec/fixtures/patch_create_delete/a_file.txt	2017-10-04 15:39:44.179306674 -0300
+++ luarocks-patch/spec/fixtures/patch_create_delete/a_file.txt	1969-12-31 21:00:00.000000000 -0300
@@ -1 +0,0 @@
-I am a file.
diff -Naur luarocks/spec/fixtures/patch_create_delete/another_file.txt luarocks-patch/spec/fixtures/patch_create_delete/another_file.txt
--- luarocks/spec/fixtures/patch_create_delete/another_file.txt	1969-12-31 21:00:00.000000000 -0300
+++ luarocks-patch/spec/fixtures/patch_create_delete/another_file.txt	2017-10-04 15:40:12.836306564 -0300
@@ -0,0 +1 @@
+I am another file.
]]
   }
}
