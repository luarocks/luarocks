SUITE: luarocks install

===============================================================================
TEST: fails with no flags or arguments
RUN: luarocks install
EXIT: 1



===============================================================================
TEST: fails with an unknown rock
RUN: luarocks install aoeuaoeuaoeiaoeuaoeua
EXIT: 1



===============================================================================
TEST: fails with an invalid .rock argument
RUN: luarocks install "invalid.rock"
EXIT: 1



===============================================================================
TEST: fails with incompatible architecture
RUN: luarocks install foo-1.0-1.impossible-x86.rock
EXIT: 1
STDERR:
--------------------------------------------------------------------------------
Incompatible architecture
--------------------------------------------------------------------------------



===============================================================================
TEST: fails if not a zip file

FILE: not_a_zipfile-1.0-1.src.rock
--------------------------------------------------------------------------------
I am not a zip file!
--------------------------------------------------------------------------------
RUN: luarocks install not_a_zipfile-1.0-1.src.rock
EXIT: 1



===============================================================================
TEST: fails with an invalid patch

FILE: invalid_patch-0.1-1.rockspec
--------------------------------------------------------------------------------
package = "invalid_patch"
version = "0.1-1"
source = {
   -- any valid URL
   url = "https://raw.github.com/keplerproject/luarocks/master/src/luarocks/build.lua"
}
description = {
   summary = "A rockspec with an invalid patch",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      build = "build.lua"
   },
   patches = {
      ["I_am_an_invalid_patch.patch"] =
[[
diff -Naur luadoc-3.0.1/src/luadoc/doclet/html.lua luadoc-3.0.1-new/src/luadoc/doclet/html.lua
--- luadoc-3.0.1/src/luadoc/doclet/html.lua2007-12-21 15:50:48.000000000 -0200
+++ luadoc-3.0.1-new/src/luadoc/doclet/html.lua2008-02-28 01:59:53.000000000 -0300
@@ -18,6 +18,7 @@
- gabba gabba gabba
+ gobo gobo gobo
]]
   }
}
--------------------------------------------------------------------------------
RUN: luarocks invalid_patch-0.1-1.rockspec
EXIT: 1



================================================================================
TEST: handle versioned modules when installing another version with --keep #268

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: myrock-2.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "2.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

RUN: luarocks build myrock-1.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks build myrock-2.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks install ./myrock-2.0-1.all.rock

EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/rock.lua

RUN: luarocks install ./myrock-1.0-1.all.rock --keep

EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/rock.lua
EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/myrock_1_0_1-rock.lua

RUN: luarocks install ./myrock-2.0-1.all.rock

EXISTS:     %{testing_sys_tree}/share/lua/%{LUA_VERSION}/rock.lua
NOT_EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/myrock_1_0_1-rock.lua



================================================================================
TEST: handle versioned libraries when installing another version with --keep #268

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/c_module.c"
}
build = {
   modules = {
      c_module = { "c_module.c" }
   }
}
--------------------------------------------------------------------------------

FILE: myrock-2.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "2.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/c_module.c"
}
build = {
   modules = {
      c_module = { "c_module.c" }
   }
}
--------------------------------------------------------------------------------
FILE: c_module.c
--------------------------------------------------------------------------------
#include <lua.h>
#include <lauxlib.h>

int luaopen_c_module(lua_State* L) {
  lua_newtable(L);
  lua_pushinteger(L, 1);
  lua_setfield(L, -2, "c_module");
  return 1;
}
--------------------------------------------------------------------------------

RUN: luarocks build myrock-1.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks build myrock-2.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks install ./myrock-2.0-1.%{platform}.rock

EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/c_module.%{lib_extension}

RUN: luarocks install ./myrock-1.0-1.%{platform}.rock --keep

EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/c_module.%{lib_extension}
EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/myrock_1_0_1-c_module.%{lib_extension}

RUN: luarocks install ./myrock-2.0-1.%{platform}.rock

EXISTS:     %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/c_module.%{lib_extension}
NOT_EXISTS: %{testing_sys_tree}/lib/lua/%{LUA_VERSION}/myrock_1_0_1-c_module.%{lib_extension}



================================================================================
TEST: installs a package with a bin entry

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" },
   install = {
      bin = {
         ["scripty"] = "rock.lua",
      }
   }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

RUN: luarocks build myrock-1.0-1.rockspec
EXISTS: %{testing_sys_tree}/bin/scripty%{wrapper_extension}
RUN: luarocks pack myrock
RUN: luarocks remove myrock
NOT_EXISTS: %{testing_sys_tree}/bin/scripty%{wrapper_extension}

RUN: luarocks install myrock-1.0-1.all.rock
EXISTS: %{testing_sys_tree}/bin/scripty%{wrapper_extension}



================================================================================
TEST: installs a package without its documentation using --no-doc

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "."
}
build = {
   modules = { rock = "rock.lua" },
   install = {
      bin = {
         ["scripty"] = "rock.lua",
      }
   }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

FILE: doc/something
--------------------------------------------------------------------------------
a doc
--------------------------------------------------------------------------------

RUN: luarocks make
EXISTS: %{testing_sys_rocks}/myrock/1.0-1/doc/something
RUN: luarocks pack myrock
RUN: luarocks remove myrock
NOT_EXISTS: %{testing_sys_rocks}/myrock/1.0-1/doc/something

RUN: luarocks install myrock-1.0-1.all.rock
EXISTS: %{testing_sys_rocks}/myrock/1.0-1/doc/something
RUN: luarocks remove myrock
NOT_EXISTS: %{testing_sys_rocks}/myrock/1.0-1/doc/something

RUN: luarocks install myrock-1.0-1.all.rock --no-doc
NOT_EXISTS: %{testing_sys_rocks}/myrock/1.0-1/doc/something



================================================================================
TEST: handle non-Lua files in build.install.lua when upgrading sailorproject/sailor#138

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "."
}
build = {
   modules = {
      rock = "rock.lua",
   },
   install = {
      lua = {
         ["sailor.blank-app.htaccess"] = "src/sailor/blank-app/.htaccess",
      }
   }
}
--------------------------------------------------------------------------------

FILE: myrock-1.0-2.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-2"
source = {
   url = "."
}
build = {
   modules = {
      rock = "rock.lua",
   },
   install = {
      lua = {
         ["sailor.blank-app.htaccess"] = "src/sailor/blank-app/.htaccess",
      }
   }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

FILE: src/sailor/blank-app/.htaccess
--------------------------------------------------------------------------------
# I am just a file
--------------------------------------------------------------------------------

Prepare two versions as .rock packages with the same non-Lua asset:

RUN: luarocks make ./myrock-1.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks make ./myrock-1.0-2.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

Now install the first one, and check that the asset was installed, with no "~"
backup leftover:

RUN: luarocks install myrock-1.0-1.all.rock --no-doc

EXISTS:     %{testing_sys_tree}/share/lua/%{LUA_VERSION}/sailor/blank-app/.htaccess
NOT_EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/sailor/blank-app/.htaccess~

Then install the second one, and the asset should be replaced, again with no
"~" backup leftover:

RUN: luarocks install myrock-1.0-2.all.rock --no-doc

EXISTS:     %{testing_sys_tree}/share/lua/%{LUA_VERSION}/sailor/blank-app/.htaccess
NOT_EXISTS: %{testing_sys_tree}/share/lua/%{LUA_VERSION}/sailor/blank-app/.htaccess~



================================================================================
TEST: do not reinstall when already installed

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

RUN: luarocks build myrock-1.0-1.rockspec
RUN: luarocks pack myrock
RUN: luarocks remove myrock

RUN: luarocks install ./myrock-1.0-1.all.rock

RUN: luarocks show myrock
STDOUT:
--------------------------------------------------------------------------------
myrock 1.0
--------------------------------------------------------------------------------

RUN: luarocks install ./myrock-1.0-1.all.rock
STDOUT:
--------------------------------------------------------------------------------
myrock 1.0-1 is already installed
Use --force to reinstall
--------------------------------------------------------------------------------



================================================================================
TEST: installation rolls back on failure

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = {
      ["folder.rock"] = "rock.lua",
      ["xyz"] = "xyz.lua",
   },
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

FILE: xyz.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

RUN: luarocks make --pack-binary-rock ./myrock-1.0-1.rockspec

FILE: %{testing_sys_tree}/share/lua/%{lua_version}/folder
--------------------------------------------------------------------------------
a file where a folder should be
--------------------------------------------------------------------------------

Try to install and fail because the file is in the folder's spot:

RUN: luarocks install ./myrock-1.0-1.all.rock
EXIT: 1

EXISTS: %{testing_sys_tree}/share/lua/%{lua_version}/folder

No leftovers from the failed installation:

NOT_EXISTS: %{testing_sys_tree}/share/lua/%{lua_version}/xyz.lua

Now we remove the file...

RM: %{testing_sys_tree}/share/lua/%{lua_version}/folder

Try again and succeed:

RUN: luarocks install ./myrock-1.0-1.all.rock

EXISTS: %{testing_sys_tree}/share/lua/%{lua_version}/folder/rock.lua
EXISTS: %{testing_sys_tree}/share/lua/%{lua_version}/xyz.lua



================================================================================
TEST: new install functionality based on #552: break dependencies warning

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: myrock-2.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "2.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: hasdep-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "hasdep"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/hasdep.lua"
}
dependencies = {
   "myrock >= 2.0",
}
build = {
   modules = { hasdep = "hasdep.lua" }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

FILE: hasdep.lua
--------------------------------------------------------------------------------
return "hasdep"
--------------------------------------------------------------------------------

RUN: luarocks build myrock-2.0-1.rockspec
RUN: luarocks build hasdep-1.0-1.rockspec
RUN: luarocks build myrock-1.0-1.rockspec

STDERR:
--------------------------------------------------------------------------------
Will not remove myrock 2.0
Removing it would break dependencies for
hasdep 1.0
--------------------------------------------------------------------------------

EXISTS: %{testing_sys_rocks}/myrock/1.0-1
EXISTS: %{testing_sys_rocks}/myrock/2.0-1



================================================================================
TEST: new install functionality based on #552: break dependencies with --force

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: myrock-2.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "2.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: hasdep-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "hasdep"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/hasdep.lua"
}
dependencies = {
   "myrock >= 2.0",
}
build = {
   modules = { hasdep = "hasdep.lua" }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

FILE: hasdep.lua
--------------------------------------------------------------------------------
return "hasdep"
--------------------------------------------------------------------------------

RUN: luarocks build myrock-2.0-1.rockspec
RUN: luarocks build hasdep-1.0-1.rockspec
RUN: luarocks build myrock-1.0-1.rockspec --force

STDERR:
--------------------------------------------------------------------------------
The following packages may be broken by this forced removal
hasdep 1.0
--------------------------------------------------------------------------------

NOT_EXISTS: %{testing_sys_rocks}/myrock/2.0-1
EXISTS: %{testing_sys_rocks}/myrock/1.0-1



================================================================================
TEST: new install functionality based on #552: break dependencies with --force-fast

FILE: myrock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: myrock-2.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "myrock"
version = "2.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/rock.lua"
}
build = {
   modules = { rock = "rock.lua" }
}
--------------------------------------------------------------------------------

FILE: hasdep-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "hasdep"
version = "1.0-1"
source = {
   url = "file://%{url(%{tmpdir})}/hasdep.lua"
}
dependencies = {
   "myrock >= 2.0",
}
build = {
   modules = { hasdep = "hasdep.lua" }
}
--------------------------------------------------------------------------------

FILE: rock.lua
--------------------------------------------------------------------------------
return "hello"
--------------------------------------------------------------------------------

FILE: hasdep.lua
--------------------------------------------------------------------------------
return "hasdep"
--------------------------------------------------------------------------------

RUN: luarocks build myrock-2.0-1.rockspec
RUN: luarocks build hasdep-1.0-1.rockspec
RUN: luarocks build myrock-1.0-1.rockspec --force-fast

NOT_STDERR:
--------------------------------------------------------------------------------
The following packages may be broken by this forced removal
hasdep 1.0
--------------------------------------------------------------------------------

NOT_EXISTS: %{testing_sys_rocks}/myrock/2.0-1
EXISTS: %{testing_sys_rocks}/myrock/1.0-1
