rockspec_format = "3.0"
package = "has_another_namespaced_dep"
version = "1.0-1"
source = {
   url = "http://localhost:8080/file/a_rock.lua"
}
description = {
   summary = "An example rockspec",
}
dependencies = {
   "another_user/a_rock",
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      bla = "a_rock.lua"
   },
}
