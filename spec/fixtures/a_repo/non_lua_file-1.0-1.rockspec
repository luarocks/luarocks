-- regression test for sailorproject/sailor#138
rockspec_format = "3.0"
package = "non_lua_file"
version = "1.0-1"
source = {
   url = "file://../upstream/non_lua_file-1.0.tar.gz"
}
description = {
   summary = "An example rockspec that has a script.",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {},
   install = {
      lua = {
         ["sailor.blank-app.htaccess"] = "src/sailor/blank-app/.htaccess",
      }
   }
}
