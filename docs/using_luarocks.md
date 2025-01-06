# Using LuaRocks

So, you have followed the installation instructions (either on
[Unix](installation_instructions_for_unix.md) or
[Windows](installation_instructions_for_windows.md)) and now you have LuaRocks
installed on your machine. Now you probably want to install some rocks
(packages containing Lua modules) and use them in your Lua code. 

For LuaRocks to function properly, we have a quick checklist to go through
first:

# Command-line tools (and the system path) 

LuaRocks installs some command-line tools which are your interface for
managing your rocks: [luarocks](luarocks.md) and
[luarocks-admin](luarocks_admin.md). Make sure the directory where they are
located is in your PATH -- the exact location depends on the flags you gave
when installing LuaRocks.

Run [luarocks](luarocks.md) to see the available commands:

```
luarocks 
```

You can get help on any command by using the [luarocks help](luarocks_help.md) command:

```
luarocks help install
```

Installing packages is done by typing commands such as:

```
luarocks install dkjson
```

# Rocks trees and the Lua libraries path 

When you install rocks using the `luarocks install`, you get new modules
available for loading via `require()` from Lua. For example, after we install
the dkjson rock, type `luarocks show dkjson` to show the module installed by
the rock:

```
luarocks show dkjson
```

This should output something like this:

```
dkjson 2.5-2 - David Kolf's JSON module for Lua
  
dkjson is a module for encoding and decoding JSON data. It supports UTF-8.
  
JSON (JavaScript Object Notation) is a format for serializing data based on the
syntax for JavaScript data structures.
  
dkjson is written in Lua without any dependencies, but when LPeg is available
dkjson uses it to speed up decoding.
  
License: 	MIT/X11
Homepage: 	http://dkolf.de/src/dkjson-lua.fsl/
Installed in: 	/usr/local
  
Modules:
	dkjson (/usr/local/share/lua/5.3/dkjson.lua)
```

It presents a short description of the rock, its license, and the list of
modules it provides (in this case, only one, `dkjson`). Note that "Installed
in:" shows the directory tree where the rock was installed. This is the "rocks
tree" in use.

Most LuaRocks installations will feature two rocks trees:

* "system" [rock tree](rocks_repositories.md) (used by default)
* "user" [rock tree](rocks_repositories.md)

To be able to use the module, we need to make sure that Lua can find that
dkjson.lua file when we run `require("dkjson")`. You can check your Lua paths
from the Lua environment, using

```
print(package.path)
print(package.cpath)
```

These variables can be pre-configured from outside Lua, using the LUA_PATH and
LUA_CPATH environment variables. 

If you installed both Lua and LuaRocks in their default directories
(/usr/local on Linux and Mac OSX), then the "system" tree is /usr/local and it
will work by default. However, the "user" tree (for installing rocks without
admin privileges) is not detected by Lua by default. For that we'll need to
configure these environment variables.

LuaRocks offers a semi-automated way to do this. If you type the following
command:

```
luarocks path --bin
```

...it will print commands suitable for your platform for setting up your
environment. On typical Unix terminal environments, you can type this:

```
eval "$(luarocks path --bin)"
```

and it apply the changes, temporarily, to your shell. To have these variables
set permanently, you have to configure the environment variables to your shell
configuration (for example, by adding the above line to your `.bashrc` file if
your shell is Bash).

# Multiple versions using the LuaRocks package loader 

If you want to make use of LuaRocks' support for multiple installed versions
of modules, you need to load a custom package loader: luarocks.loader.

You should be able to launch the Lua interpreter with the LuaRocks-enabled
loader by typing:

```
lua -lluarocks.loader
```

Alternatively, you can load the LuaRocks module loader from Lua by issuing
this command:

```
require "luarocks.loader"
```

If your system is correctly set up so that this command runs with no errors,
subsequent calls to `require()` are LuaRocks-aware and the exact version of
each module will be determined based on the dependency tree of previously
loaded modules. 

# Scripts installed by rocks (and the scripts path) 

Besides modules, rocks can also install command-line scripts. The default
location of this directory (unless you configured your local repository
differently) is /usr/local/bin for system-wide installs and ~/.luarocks/bin
for per-user installs on Unix and %APPDATA%/luarocks/bin on Windows -- make
sure it is in your PATH as well.

If you use the `--bin` argument in `luarocks path`, it will also print the
appropriate PATH configuration:

```
luarocks path --bin
```

# Using in Unix systems with sudo 

When you use LuaRocks to install a package while you aren't root, the package
will get installed in $HOME/.luarocks/ instead of the system-wide (by default,
/usr/local/) and become only available for you. Moreover Lua doesn't know with
its default setup that packages can be available in the current user's home.
If you want to install a package available for all users, you should run it as
superuser, typically using sudo.

For example:

```
sudo luarocks install stdlib
```

After that, some files may not have correct permissions. For example, if
/usr/local/share/lua/5.1/base.lua is only readable by root user, you should at
least set them to readable for all users (chmod a+r or chmod 644).

For example:

```
cd /usr/local/share/lua/5.1
 sudo chmod a+r *
```

# Using a C compiler 

Because rocks are generally available in the repository as [source
rocks](types_of_rocks.md) rather than binary rocks, it is best to have a C
compiler available.

On Windows, MinGW and Microsoft compilers are supported. The compiler should
be in the system path, or explicitly configured in the LuaRocks config files.
On Windows systems, one way of getting the compiler in the system path is to
open the appropriate command prompt as configured by your compiler package
(for example, the MSVC Command Prompt for Visual Studio).

Note that for compiling binary rocks that have dependencies on other
libraries, LuaRocks needs to be able to find [external
dependencies](paths_and_external_dependencies.md).


