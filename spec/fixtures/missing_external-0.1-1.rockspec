package = "missing_external"
version = "0.1-1"
source = {
   -- any valid URL
   url = "https://raw.github.com/keplerproject/luarocks/master/src/luarocks/build.lua"
}
description = {
   summary = "Missing external dependency",
}
external_dependencies = {
   INEXISTENT = {
      library = "inexistentlib*",
      header = "inexistentheader*.h",
   }
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      build = "build.lua"
   }
}
