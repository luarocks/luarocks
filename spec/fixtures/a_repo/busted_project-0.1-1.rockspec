rockspec_format = "3.0"
package = "busted_project"
version = "0.1-1"
source = {
   url = "http://localhost:8080/file/busted_project-0.1.tar.gz",
   dir = "busted_project",
}
description = {
   summary = "A project that uses Busted tests",
}
build = {
   type = "builtin",
   modules = {
      sum = "sum.lua",
   }
}
test = {
   type = "busted",
}
