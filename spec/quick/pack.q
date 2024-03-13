SUITE: luarocks pack

================================================================================
TEST: fails no arguments

RUN: luarocks pack
EXIT: 1



================================================================================
TEST: fails with invalid rockspec

RUN: luarocks pack $%{fixtures_dir}/invalid_say-1.3-1.rockspec
EXIT: 1



================================================================================
TEST: fails with rock that is not installed

RUN: luarocks pack notinstalled
EXIT: 1



================================================================================
TEST: fails with non existing path

RUN: luarocks pack /notexists/notinstalled
EXIT: 1



================================================================================
TEST: packs latest version version of rock

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
RUN: luarocks build myrock-2.0-1.rockspec --keep
RUN: luarocks pack myrock

EXISTS: myrock-2.0-1.all.rock



================================================================================
TEST: --sign #gpg
PENDING: true

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
RUN: luarocks build myrock-2.0-1.rockspec --keep
RUN: luarocks pack myrock --sign

EXISTS: myrock-2.0-1.all.rock
EXISTS: myrock-2.0-1.all.rock.asc



================================================================================
TEST: packs a namespaced rock #namespaces

RUN: luarocks build a_user/a_rock --server=%{fixtures_dir}/a_repo
RUN: luarocks build a_rock --keep --server=%{fixtures_dir}/a_repo
RUN: luarocks pack a_user/a_rock

EXISTS: a_rock-2.0-1.all.rock
