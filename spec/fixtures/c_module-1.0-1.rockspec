package = "c_module"
version = "1.0-1"
source = {
   url = "http://example.com/c_module"
}
build = {
   type = "builtin",
   modules = {
      c_module = { "c_module.c" }
   }
}
