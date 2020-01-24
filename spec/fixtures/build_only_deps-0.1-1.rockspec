package = "build_only_deps"
version = "0.1-1"
source = {
   url = "file://./a_rock.lua"
}
description = {
   summary = "Fixture to test --only-deps",
}
dependencies = {
   "lua >= 5.1",
   "a_rock 1.0",
}
build = {
   type = "builtin",
   modules = {
      dummy = "a_rock.lua",
   }
}
