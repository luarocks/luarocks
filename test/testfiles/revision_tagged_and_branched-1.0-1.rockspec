rockspec_format = "3.0"
package = "revision_tagged_and_branched"
version = "1.0-1"
source = {
   url = "git://github.com/Alloyed/git_test",
   branch = "mybranch",
   tag = "#mybranch.2",
   revision = "e97925b86a15227ddd4c232dc62db683f7ee1c3c"
}
description = {
   homepage = "https://github.com/Alloyed/git_test",
}
dependencies = {}
build = {
   type = "builtin",
   modules = {}
}
