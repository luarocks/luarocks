rockspec_format = "3.0"
package = "a_build_dep"
version = "1.0-1"
source = {
   url = "http://localhost:8080/file/a_rock.lua"
}
description = {
   summary = "An example rockspec that is a build dependency for has_build_dep.",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      build_dep = "a_rock.lua"
   },
}
