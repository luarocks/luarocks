rockspec_format = "3.0"
package = "luajit-success"
version = "1.0-1"
source = {
   url = "https://raw.githubusercontent.com/keplerproject/luarocks/master/test/testing.lua",
}
description = {
   summary = "Test luajit dependency fail",
   detailed = [[
Use luajit dependency when running with rockspec_format >= 3.0.
]],
   homepage = "http://luarocks.org/",
   license = "MIT/X license"
}
dependencies = {
   "luajit >= 2.0"
}
build = {
   type = "builtin",
   modules = {
      testing = "testing.lua"
   }
}
