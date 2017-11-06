package = "with_external_dep"
version = "0.1-1"
source = {
   url = "http://localhost:8080/file/with_external_dep.c"
}
description = {
   summary = "An example rockspec",
}
external_dependencies = {
   FOO = {
      header = "foo/foo.h"
   }
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      with_external_dep = {
         sources = "with_external_dep.c",
         incdirs = "$(FOO_INCDIR)",
      }
   }
}
