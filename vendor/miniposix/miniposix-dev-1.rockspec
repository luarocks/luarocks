package = "miniposix"
version = "dev-1"
source = {
   url = "./miniposix.c",
}
description = {
   summary = "Minimal set of posix functions used by LuaRocks",
   license = "MIT/X11",
}
build = {
   type = "builtin",
   modules = {
      ["miniposix"] = "miniposix.c"
   }
}
