package = "with_dep"
version = "0.1-1"
source = {
   url = "http://localhost:8080/file/with_dep.lua"
}
description = {
   summary = "An example rockspec",
}
dependencies = {
   "lua >= 5.1",
   "with_external_dep 0.1",
}
build = {
   type = "builtin",
   modules = {
      with_dep = "with_dep.lua"
   }
}
