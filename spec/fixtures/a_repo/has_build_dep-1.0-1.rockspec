rockspec_format = "3.0"
package = "has_build_dep"
version = "1.0-1"
source = {
   url = "http://localhost:8080/file/a_rock.lua"
}
description = {
   summary = "An example rockspec that has build dependencies.",
}
dependencies = {
   "a_rock",
   "lua >= 5.1",
}
build_dependencies = {
   "a_build_dep",
}
build = {
   type = "builtin",
   modules = {
      bla = "a_rock.lua"
   },
}
