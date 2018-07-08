package = "a_rock"
version = "3.0-1"
source = {
   url = "http://localhost:8080/file/a_rock.lua"
}
description = {
   summary = "An example rockspec",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      a_rock = "a_rock.lua"
   },
}
