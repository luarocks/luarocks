# Paths and external dependencies

Many Lua rocks are bindings to C libraries: for example,
[luaossl](https://luarocks.org/modules/daurnimator/luaossl) is a binding
library to the [OpenSSL](https://openssl.org) library. This means that, in our
example, luaossl _depends on_ OpenSSL. But since this is not a regular
rock-to-rock dependency (if it were, LuaRocks could solve this by itself), we
call this an **external dependency**.

When building a rock with external dependencies, LuaRocks needs to make sure
the necessary C libraries and headers are installed, and know where those C
libraries are.

## Specifying external dependencies in your rockspecs

When writing a rock with external dependencies, one needs to be careful to
avoid the "works on my machine" situation: when you write code that hardcodes
the location of external dependencies as they are in your system, but then
fails to build in other people's systems. 

The way to avoid this problem is to avoid any hardcoded paths. Instead, the
`build` section of a [rockspec](rockspec_format.md) should make use of path
variables. If not using the `builtin` build type, paths set by the module's
own build system must not be relied on and explicit paths should be passed to
it by the rockspec instead.

Paths where LuaRocks should install files into are defined as the `PREFIX`,
`LUADIR`, `LIBDIR` and `BINDIR` variables. (See the [Config file
format](config_file_format.md) page for details.)

Paths for external dependencies (such as C libraries used in the compilation
of modules) are generated from the `external_dependencies` section of the
rockspec (see the [Rockspec format](rockspec_format.md) page for details.) Lua
itself is considered a special external dependency.

These path variables are set in the global `variables` table defined in the
[config file](config_file_format.md). Their values are populated automatically
by LuaRocks, but can be overriden by the user (either by setting them directly
in the config file, or by passing them through the "luarocks" command line). 

The `variables` table always contains entries for `LUA_BINDIR`, `LUA_INCDIR`
and `LUA_LIBDIR`. Like the other external dependency variables, these can be
overriden in the LuaRocks config file or in the command line.