rockspec_format = "3.0"
package = "revision_beats_tag"
version = "1.0-1"
-- To be consistent with how tags beat branches, revisions should beat tags.
source = {
   url = "git://github.com/Alloyed/git_test",
   tag = "#2",
   -- change #1 on master
   revision = "4d1e421287df69fad1338a45591c27116c6736ab"
}
description = {
   homepage = "https://github.com/Alloyed/git_test",
}
dependencies = {}
build = {
   type = "builtin",
   modules = {}
}
