package = "say"
version = "1.3-1"
source = {{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{++{
  url = "https://github.com/Olivine-Labs/say/archive/v1.3-1.tar.gz",
  dir = "say-1.3-1"
}
description = {
  summary = "Lua String Hashing/Indexing Library",
  detailed = [[
    Useful for internationalization.
  ]],
  homepage = "http://olivinelabs.com/busted/",
  license = "MIT <http://opensource.org/licenses/MIT>"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["say.init"] = "src/init.lua"
  }
}
