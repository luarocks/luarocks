SUITE: luarocks build

================================================================================
TEST: fails when given invalid argument
RUN: luarocks build aoesuthaoeusahtoeustnaou --only-server=localhost
EXIT: 1
STDERR:
--------------------------------------------------------------------------------
Could not find a result named aoesuthaoeusahtoeustnaou
--------------------------------------------------------------------------------



================================================================================
TEST: with no arguments behaves as luarocks make

FILE: c_module-1.0-1.rockspec
--------------------------------------------------------------------------------
package = "c_module"
version = "1.0-1"
source = {
   url = "http://example.com/c_module"
}
build = {
   type = "builtin",
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
RUN: luarocks build
EXISTS: c_module.%{lib_extension}



================================================================================
TEST: defaults to builtin type

FILE: a_rock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "a_rock"
version = "1.0-1"
source = {
   url = "file://%{url(%{fixtures_dir})}/a_rock.lua"
}
description = {
   summary = "An example rockspec",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   modules = {
      build = "a_rock.lua"
   },
}
--------------------------------------------------------------------------------
RUN: luarocks build a_rock-1.0-1.rockspec
RUN: luarocks show a_rock
STDOUT:
--------------------------------------------------------------------------------
a_rock 1.0
--------------------------------------------------------------------------------


================================================================================
TEST: fails if no permissions to access the specified tree #unix

RUN: luarocks build --tree=/usr ./a_rock-1.0.1-rockspec
EXIT: 4
STDERR:
--------------------------------------------------------------------------------
requires exclusive write access
--------------------------------------------------------------------------------

We show the OS permission denied error, so we don't show the --force-lock
message.

NOT_STDERR:
--------------------------------------------------------------------------------
try --force-lock
--------------------------------------------------------------------------------

NOT_EXISTS: %{testing_sys_rocks}/a_rock/1.0-1/a_rock-1.0-1.rockspec

RUN: luarocks build --tree=/usr ./a_rock-1.0.1-rockspec --force-lock
EXIT: 4
STDERR:
--------------------------------------------------------------------------------
requires exclusive write access
--------------------------------------------------------------------------------

We show the OS permission denied error, so we don't show the --force-lock
message.

NOT_STDERR:
--------------------------------------------------------------------------------
try --force-lock
--------------------------------------------------------------------------------

NOT_EXISTS: %{testing_sys_rocks}/a_rock/1.0-1/a_rock-1.0-1.rockspec



================================================================================
TEST: fails if no permissions to access the parent #unix

RUN: luarocks build --tree=/usr/invalid ./a_rock-1.0.1-rockspec
EXIT: 4
STDERR:
--------------------------------------------------------------------------------
requires exclusive write access
--------------------------------------------------------------------------------

We show the OS permission denied error, so we don't show the --force-lock
message.

NOT_STDERR:
--------------------------------------------------------------------------------
try --force-lock
--------------------------------------------------------------------------------

NOT_EXISTS: %{testing_sys_rocks}/a_rock/1.0-1/a_rock-1.0-1.rockspec

RUN: luarocks build --tree=/usr/invalid ./a_rock-1.0.1-rockspec --force-lock
EXIT: 4
STDERR:
--------------------------------------------------------------------------------
requires exclusive write access
failed to force the lock
--------------------------------------------------------------------------------

NOT_EXISTS: %{testing_sys_rocks}/a_rock/1.0-1/a_rock-1.0-1.rockspec



================================================================================
TEST: luarocks build: do not rebuild when already installed

FILE: a_rock-1.0-1.rockspec
--------------------------------------------------------------------------------
rockspec_format = "3.0"
package = "a_rock"
version = "1.0-1"
source = {
   url = "file://%{url(%{fixtures_dir})}/a_rock.lua"
}
description = {
   summary = "An example rockspec",
}
dependencies = {
   "lua >= 5.1"
}
build = {
   modules = {
      build = "a_rock.lua"
   },
}
--------------------------------------------------------------------------------
RUN: luarocks build a_rock-1.0-1.rockspec

RUN: luarocks show a_rock
STDOUT:
--------------------------------------------------------------------------------
a_rock 1.0
--------------------------------------------------------------------------------

RUN: luarocks build a_rock-1.0-1.rockspec
STDOUT:
--------------------------------------------------------------------------------
a_rock 1.0-1 is already installed
Use --force to reinstall
--------------------------------------------------------------------------------



================================================================================
TEST: supports --pin #pinning

FILE: test-1.0-1.rockspec
--------------------------------------------------------------------------------
package = "test"
version = "1.0-1"
source = {
   url = "file://%{url(tmpdir)}/test.lua"
}
dependencies = {
   "a_rock >= 0.8"
}
build = {
   type = "builtin",
   modules = {
      test = "test.lua"
   }
}
--------------------------------------------------------------------------------

FILE: test.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

RUN: luarocks build --only-server=%{fixtures_dir}/a_repo test-1.0-1.rockspec --pin --tree=lua_modules

EXISTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/test/1.0-1/test-1.0-1.rockspec
EXISTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/a_rock/2.0-1/a_rock-2.0-1.rockspec

EXISTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/test/1.0-1/luarocks.lock

FILE_CONTENTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/test/1.0-1/luarocks.lock
--------------------------------------------------------------------------------
return {
   dependencies = {
      a_rock = "2.0-1",
      lua = "%{lua_version}-1"
   }
}
--------------------------------------------------------------------------------



================================================================================
TEST: supports --pin --only-deps #pinning

FILE: test-1.0-1.rockspec
--------------------------------------------------------------------------------
package = "test"
version = "1.0-1"
source = {
   url = "file://%{url(tmpdir)}/test.lua"
}
dependencies = {
   "a_rock >= 0.8"
}
build = {
   type = "builtin",
   modules = {
      test = "test.lua"
   }
}
--------------------------------------------------------------------------------

FILE: test.lua
--------------------------------------------------------------------------------
return {}
--------------------------------------------------------------------------------

RUN: luarocks build --only-server=%{fixtures_dir}/a_repo test-1.0-1.rockspec --pin --only-deps --tree=lua_modules

NOT_EXISTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/test/1.0-1/test-1.0-1.rockspec
EXISTS: ./lua_modules/lib/luarocks/rocks-%{lua_version}/a_rock/2.0-1/a_rock-2.0-1.rockspec

EXISTS: ./luarocks.lock

FILE_CONTENTS: ./luarocks.lock
--------------------------------------------------------------------------------
return {
   dependencies = {
      a_rock = "2.0-1",
      lua = "%{lua_version}-1"
   }
}
--------------------------------------------------------------------------------
