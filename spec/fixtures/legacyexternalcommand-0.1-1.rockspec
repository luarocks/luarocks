package = "legacyexternalcommand"
version = "0.1-1"
source = {
   url = "http://localhost:8080/file/legacyexternalcommand.lua"
}
description = {
   summary = "an external command with legacy arg parsing",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["luarocks.cmd.external.legacyexternalcommand"] = "legacyexternalcommand.lua",
   }
}
