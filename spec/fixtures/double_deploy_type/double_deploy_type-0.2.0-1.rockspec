package = "double_deploy_type"
version = "0.2.0-1"
source = {
   url = "http://example.com"
}
description = {
   homepage = "http://example.com",
   license = "*** please specify a license ***"
}
dependencies = {}
build = {
   type = "builtin",
   modules = {
      ddt = "ddt/ddt.c"
   },
   install = {
      lua = {
         ddt = "ddt/ddt2.lua",
         ddt_file = "ddt/ddt_file",
      }
   }
}
