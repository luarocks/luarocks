rockspec_format = "3.0"
package = "revision_not_on_branch"
version = "1.0-1"
source = {
   url = "git://github.com/Alloyed/git_test",
   branch = "mybranch",
   -- change #3 on master
   revision = "56bc5ec9dc03e3f05cfa39b292e116b07d44c90e"
}
description = {
   homepage = "https://github.com/Alloyed/git_test",
}
dependencies = {}
build = {
   type = "builtin",
   modules = {}
}
