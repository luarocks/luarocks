# File locations

This is a summary of all file paths related to LuaRocks, including the files
that compose LuaRocks (its scripts and modules), files installed by LuaRocks
(Lua modules and scripts), and files required by LuaRocks (programs, libraries
and headers).

For each path, the default value is also listed.

Whenever "5.x" is used, it refers to the Lua version you configured during
installation.

# Path to LuaRocks 

* LuaRocks command-line scripts. These are the main LuaRocks commands
  (`luarocks`, `luarocks-admin`); it should be in your system PATH.

  * Unix default: /usr/local/bin

* LuaRocks modules. These are Lua modules (`luarocks.fs`, etc.) used by
  LuaRocks. The LuaRocks command-line tools are configured during installation
  to be able to find those files.

  * Unix default: /usr/local/share/lua/5.x/

# Path to Lua binaries and associated data 

* Lua interpreter. Where to find the Lua interpreter to execute scripts and
  LuaRocks itself.

  * Unix default: /usr/local/bin/lua

* Lua libraries. The directory containing the Lua virtual machine as a shared
  library. On some platforms, Lua modules written in C (also called "C
  modules") should link against this library

  * Unix default: /usr/local/lib

* Lua header files (lua.h, etc.). They are required when compiling C modules.

  * Unix default: /usr/local/include

On Unix, those locations vary according to your OS variant or distribution. If
you're using a Linux distribution, for example, you may have installed Lua
using your package manager and paths use /usr/ rather than /usr/local/, and
the `lua` binary may be called `lua-5.x`.

For Windows users, having libraries and headers around may be uncommon, as
Windows tends to have binary distributions. LuaRocks can provide binary rocks,
but rocks in the standard repository are often available only as source code
and need to be compiled during the installation process.

# Paths to rocks trees 

LuaRocks by default is configured to use two rocks trees:

* System-wide [rock tree](rocks_repositories.md) (used by default)
  * Unix default: /usr/local/
* Per-user [rock tree](rocks_repositories.md) (may be selected by the user with the --local flag).
  * Unix default: $HOME/.luarocks/

In order to use the modules installed in the rock trees, the [deployment
directories](rocks_repositories.md) should be in the `LUA_PATH` and
`LUA_CPATH` environment variables. 

On Unix, performing a vanilla installation of Lua from lua.org and a vanilla
installation of LuaRocks will install both under /usr/local, meaning that the
environment variables for the system-wide rock tree are correct by default.

The command `[luarocks path](luarocks_path.md)` outputs the correct environment
variables set for a rock tree.

# Path where command-line scripts are installed 

Rocks may also deploy command-line scripts. This location is relative to the
rock tree where they are installed:

* System-wide [rock tree](rocks_repositories.md) (used by default)

  * Unix default: /usr/local/bin/

* Per-user [rock tree](rocks_repositories.md) (may be selected by the user
  with the --local flag).

  * Unix default: $HOME/.luarocks/bin/

To be able to call those scripts from the shell, the location where they are
installed need to be in your environment path. 

On Unix, /usr/local/bin is usually in the $PATH by default, but
$HOME/.luarocks/bin is not. 

The command `[luarocks path](luarocks_path.md) --bin` outputs the correct PATH
environment variables set for a rock tree.

# Compiler 

For compiling modules written in C, you need a compiler toolchain installed.

For many platforms this is a non-issue: Linux distribution often include
`gcc` (the default installation of Ubuntu, notably, ships without build
tools by default: run `sudo apt-get install build-essential`).

On Windows, where binary distribution is the standard, this might be an
additional requirement. Because more rocks are available as source code than
as binary rocks, it is probably best to have a C compiler available. LuaRocks
supports MinGW and the Microsoft Visual Studio toolchains. The compiler should
be in the system path, or explicitly configured in the LuaRocks config files.


