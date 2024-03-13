SUITE: luarocks new_version

================================================================================
TEST: fails without a context

RUN: luarocks new_version
EXIT: 1



================================================================================
TEST: fails with invalid arg

RUN: luarocks new_version i_dont_exist
EXIT: 1



================================================================================
TEST: updates a version

FILE: myexample-0.1-1.rockspec
--------------------------------------------------------------------------------
package = "myexample"
version = "0.1-1"
source = {
   url = "git+https://localhost/myexample.git",
   tag = "v0.1"
}
description = {
   summary = "xxx",
   detailed = "xxx"
}
build = {
   type = "builtin",
   modules = {
      foo = "src/foo.lua"
   }
}
--------------------------------------------------------------------------------

RUN: luarocks new_version myexample-0.1-1.rockspec 0.2

FILE_CONTENTS: myexample-0.2-1.rockspec
--------------------------------------------------------------------------------
package = "myexample"
version = "0.2-1"
source = {
   url = "git+https://localhost/myexample.git",
   tag = "v0.2"
}
description = {
   summary = "xxx",
   detailed = "xxx"
}
build = {
   type = "builtin",
   modules = {
      foo = "src/foo.lua"
   }
}
--------------------------------------------------------------------------------



================================================================================
TEST: updates via tag

FILE: myexample-0.1-1.rockspec
--------------------------------------------------------------------------------
package = "myexample"
version = "0.1-1"
source = {
   url = "git+https://localhost/myexample.git",
   tag = "v0.1"
}
description = {
   summary = "xxx",
   detailed = "xxx"
}
build = {
   type = "builtin",
   modules = {
      foo = "src/foo.lua"
   }
}
--------------------------------------------------------------------------------

RUN: luarocks new_version myexample-0.1-1.rockspec --tag v0.2

FILE_CONTENTS: myexample-0.2-1.rockspec
--------------------------------------------------------------------------------
package = "myexample"
version = "0.2-1"
source = {
   url = "git+https://localhost/myexample.git",
   tag = "v0.2"
}
description = {
   summary = "xxx",
   detailed = "xxx"
}
build = {
   type = "builtin",
   modules = {
      foo = "src/foo.lua"
   }
}
--------------------------------------------------------------------------------



================================================================================
TEST: updates URL

FILE: myexample-0.1-1.rockspec
--------------------------------------------------------------------------------
package = "myexample"
version = "0.1-1"
source = {
   url = "https://localhost/myexample-0.1.tar.gz",
}
description = {
   summary = "xxx",
   detailed = "xxx"
}
build = {
   type = "builtin",
   modules = {
      foo = "src/foo.lua"
   }
}
--------------------------------------------------------------------------------

RUN: luarocks new_version myexample-0.1-1.rockspec 0.2 https://localhost/newpath/myexample-0.2.tar.gz

FILE_CONTENTS: myexample-0.2-1.rockspec
--------------------------------------------------------------------------------
package = "myexample"
version = "0.2-1"
source = {
   url = "https://localhost/newpath/myexample-0.2.tar.gz"
}
description = {
   summary = "xxx",
   detailed = "xxx"
}
build = {
   type = "builtin",
   modules = {
      foo = "src/foo.lua"
   }
}
--------------------------------------------------------------------------------



================================================================================
TEST: updates MD5

FILE: test-1.0-1.rockspec
--------------------------------------------------------------------------------
package = "test"
version = "1.0-1"
source = {
   url = "file://%{url(%{fixtures_dir})}/an_upstream_tarball-0.1.tar.gz",
   md5 = "dca2ac30ce6c27cbd8dac4dd8f447630",
}
build = {
   type = "builtin",
   modules = {
      my_module = "src/my_module.lua"
   },
   install = {
      bin = {
         "src/my_module.lua"
      }
   }
}
--------------------------------------------------------------------------------

RUN: luarocks new_version test-1.0-1.rockspec 2.0 file://%{url(%{fixtures_dir})}/busted_project-0.1.tar.gz

FILE_CONTENTS: test-2.0-1.rockspec
--------------------------------------------------------------------------------
package = "test"
version = "2.0-1"
source = {
   url = "file://%{url(%{fixtures_dir})}/busted_project-0.1.tar.gz",
   md5 = "adfdfb8f1caa2b1f935a578fb07536eb",
}
build = {
   type = "builtin",
   modules = {
      my_module = "src/my_module.lua"
   },
   install = {
      bin = {
         "src/my_module.lua"
      }
   }
}
--------------------------------------------------------------------------------



================================================================================
TEST: takes a URL, downloads and bumps revision by default

RUN: luarocks new_version file://%{url(%{fixtures_dir})}/a_rock-1.0-1.rockspec

EXISTS: a_rock-1.0-1.rockspec
EXISTS: a_rock-1.0-2.rockspec
