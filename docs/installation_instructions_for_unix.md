# Installation instructions for Unix

First of all, get the [latest ".tar.gz" package
here](http://luarocks.github.io/luarocks/releases).

The LuaRocks build system for Unix is based on a simple "configure" script and
a Makefile. The "configure" script offers some flags that are useful for
different models of use of LuaRocks. Run `./configure --help` for details.

## Quick start

To get a default installation of Lua and LuaRocks under `/usr/local`:

First, ensure that you have development tools installed on your system,
otherwise run the command below to install them.

For Ubuntu/Debian systems, this should do it:

``` 
-$ sudo apt install build-essential libreadline-dev unzip
```

For Yum-based distributions, try this:

``` 
-$ sudo yum install libtermcap-devel ncurses-devel libevent-devel readline-devel
```

Then, to build and install Lua, either install it using your package
manager of choice, or run the following commands to download the
package tarball, extract, build and install it. (Replace 5.3.5 with the
latest Lua version.)

```
-$ curl -R -O http://www.lua.org/ftp/lua-5.3.5.tar.gz
-$ tar -zxf lua-5.3.5.tar.gz
-$ cd lua-5.3.5
-$ make linux test
-$ sudo make install
```

Once Lua and its dependencies are installed, it is time to install LuaRocks:

* Download and unpack [latest ".tar.gz" file](http://luarocks.github.io/luarocks/releases).

* Run `./configure --with-lua-include=/usr/local/include`. (This will attempt
  to detect your installation of Lua. If you get any error messages, see the
  section [Customizing your settings](#customizing-your-settings), below.)

* Run `make`.

* As superuser, run `make install`.

Installation should be done! Run `luarocks` with no arguments to 
see a summary of your settings.

This should be sufficient. For more information and installation options, read on.

## The default settings

The default settings are suitable for installing LuaRocks globally in your
system while allowing both system-wide and per-user sets of rocks. User
accounts will be able to install their own rocks in their $HOME directory, and
the superuser can install rocks that will be available for everyone.

By default LuaRocks will install itself in `/usr/local`, like Lua, and will
use `/usr/local/etc/luarocks/config.lua` as a default path for the
configuration file. The default system-wide rocks trees is configured as
`/usr/local/lib/luarocks`, and per-user rocks install at
`$HOME/.luarocks/rocks/`. Command-line scripts provided by rocks will be
installed in `/usr/local/lib/luarocks/bin/` or `$HOME/.luarocks/bin/`,
respectively. The user may then add these directories to their `$PATH`
variable.

## Customizing your settings

All paths described above can be overridden with flags in the `configure`
script, or entries in the configuration file. These are the supported flags,
as presented by the `--help` option:

```
Installation directories:
  --prefix=PREFIX              Directory where LuaRocks should be installed,
                               Default is '/usr/local'

By default, `make install' will install all the files in `/usr/local',
`/usr/local/lib' etc.  You can specify an installation prefix other than
`/usr/local/' using `--prefix', for instance `--prefix=$HOME'.

For better control, use the options below.

Fine tuning of the installation directories:
  --sysconfdir=SYSCONFDIR      Directory for single-machine config.
                               Default is PREFIX/etc

Where to install files provided by rocks:
  --rocks-tree=DIR             Root of the local tree of installed rocks.
                               To make files installed in this location
                               accessible to Lua and your $PATH, see
                               "luarocks path --help" after installation.
                               Avoid using paths controlled by your
                               system's package manager, such as /usr.
                               - Default is PREFIX

Where is your Lua interpreter:
  --lua-version=VERSION        Use specific Lua version: 5.1, 5.2, 5.3, or 5.4
                               - Default is auto-detected.
  --with-lua-bin=LUA_BINDIR    Location of your Lua binar(y/ies).
                               - Default is the directory of the
                               auto-detected Lua interpreter,
                               (or DIR/bin if --with-lua is used)
  --with-lua=LUA_DIR           Use Lua from given directory. Default is LUA_BINDIR/..
  --with-lua-include=DIR       Lua's includes dir. Default is LUA_DIR/include
  --with-lua-lib=DIR           Lua's libraries dir. Default is LUA_DIR/lib
  --with-lua-interpreter=NAME  Lua interpreter name.
                               - Default is to auto-detected

For specialized uses of LuaRocks:
  --force-config               Force using a single config location.
                               Do not honor the $LUAROCKS_CONFIG_5_x
                               or $LUAROCKS_CONFIG environment
                               variable or the user's local config.
                               Useful to avoid conflicts when LuaRocks
                               is embedded within an application.
  --disable-incdir-check       If you do not wish to use "luarocks build",
                               (e.g. when only deploying binary packages)
                               you do not need lua.h installed. This flag
                               skips the check for lua.h in "configure".

```

After installation, a default config file called config.lua will be installed
at the directory defined by `--sysconfdir`. For further configuration of
LuaRocks paths, see the [Config file format](config_file_format.md).

## Next steps

Once LuaRocks is installed, learn more about [using LuaRocks](using_luarocks.md).


