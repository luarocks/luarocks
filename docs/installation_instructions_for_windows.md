# Installation instructions for Windows

There are two packages for Windows:

* if you already have a Lua installation, the <b>single binary</b> package
  which you can use: get the [latest windows-32.zip file
  here](http://luarocks.github.io/luarocks/releases), unpack it and you'll
  have a <tt>luarocks.exe</tt> ready to use. Make sure the executable is
  available from your executable PATH so you can run <tt>luarocks</tt> from
  the command line the same way you run <tt>lua</tt>.

* we also provide an all-in-one package which includes Lua 5.1 and LuaRocks in
  source format; get the [latest win32.zip file
  here](http://luarocks.github.io/luarocks/releases). The instructions below
  are about this package.

This page refers to the second method. The all-in-one package includes
everything you need to launch LuaRocks, including helper binaries and a
Lua interpreter. (You can use your own Lua interpreter if you already have
one installed, see below.)

<b>Important:</b> To compile many Lua packages, you will also need a C compiler.
The installer batch file included in the all-in-one package attempts to detect
if you have Microsoft Visual Studio or [Mingw](https://mingw.org) (Minimalistic GNU for Windows, which includes GCC).

The installer script, <tt>INSTALL.BAT</tt>, provides a number of options for
customizing your installation. Run <tt>INSTALL /?</tt> for details.

Run `INSTALL.BAT` it from a Command Prompt window. If you will be using it
with Microsoft Visual Studio, it is recommended to use LuaRocks with the
Visual Studio Command Prompt, where all environment variables for using the
MSVC compiler, `cl`, are set.

* If you using <a href="https://www.cygwin.com/">Cygwin</a> then go through [installation instructions for Unix](installation_instructions_for_unix.md).

# The default settings 

The default settings are suitable for installing LuaRocks globally
in your system while allowing both system-wide and per-user sets of rocks.
Non-priviledged accounts will be able to install their own rocks in their
%APPDATA% directory, and administrator accounts can install rocks that
will be available for everyone.

# Making a system-wide repository 

All paths described above can be overridden with flags in the INSTALL.BAT script,
or entries in the configuration file.

{|
| /P _dir_       || Where to install. Default is %PROGRAMFILES%\LuaRocks\_version_. Because LuaRocks contains 32bit executables, this will be in the c:\program files (x86)\ path on 64bit systems.
|}

Configuring the destinations:

{| cellpadding=5px
| /TREE _dir_    || Root of the local tree of installed rocks. Default is %PROGRAMFILES%\LuaRocks\systree. On 64bit systems this default depends on the Lua interpreter used. A 64bit interpreter will have the c:\program files\ path, where a 32bit interpreter on a 64bit system will follow the c:\program files (x86)\ path.
|-------------------------------------------------------------------------
| /SCRIPTS _dir_ || Where to install commandline scripts installed by rocks. Default is {TREE}/bin.
|-------------------------------------------------------------------------
| /CONFIG _dir_  || Location where the config file should be installed. Default is to follow /P option
|-------------------------------------------------------------------------
| /SELFCONTAINED   || Creates a self contained installation in a single directory given by /P. Sets the /TREE and /CONFIG options to the same location as /P. And does not load registry info with option /NOREG. The only option NOT self contained is the user rock tree, so don't use that if you create a self contained installation.
|}

Configuring the Lua interpreter:

{| cellpadding=5px
| /LV _version_  || Lua version to use; either 5.1, 5.2 or 5.3. Default is auto-detected.
|-------------------------------------------------------------------------
| /LUA _dir_     || Location where Lua is installed - e.g. c:\lua\5.1\. If not provided, the installer will search the system path and some default locations for a valid Lua installation. This is the base directory, the installer will look for subdirectories bin, lib, include. Alternatively these can be specified explicitly using the /INC, /LIB, and /BIN options.
|-------------------------------------------------------------------------
| /INC _dir_     || Location of Lua includes - e.g. c:\lua\5.1\include. If provided overrides sub directory found using /LUA.
|-------------------------------------------------------------------------
| /LIB _dir_     || Location of Lua libraries (.dll/.lib) - e.g. c:\lua\5.1\lib. If provided overrides sub directory found using /LUA.
|-------------------------------------------------------------------------
| /BIN _dir_     || Location of Lua executables - e.g. c:\lua\5.1\bin. If provided overrides sub directory found using /LUA.
|-------------------------------------------------------------------------
| /L             || Install LuaRocks' own copy of Lua even if detected, this will always be a 5.1 installation. (/LUA, /INC, /LIB, /BIN cannot be used with /L)
within an application.
|}

Compiler configuration:

{| cellpadding=5px
| /MW             || Use mingw as build system instead of MSVC.
|}

Other options:

{| cellpadding=5px
| /FORCECONFIG   || Use a single config location. Do not use the LUAROCKS_CONFIG variable or the user's home directory. Useful to avoid conflicts when LuaRocks is embedded 
|-------------------------------------------------------------------------
| /F             || Force. Remove installation directory if it already exists.
|-------------------------------------------------------------------------
| /NOREG         || Do not load registry info to register '.rockspec' extension with LuaRocks commands (right-click).
|-------------------------------------------------------------------------
| /NOADMIN       || The installer requires admin priviledges. If not available it will elevate a new process. Use this switch to prevent elevation, but make sure the destination paths are all accessible for the current user.
|-------------------------------------------------------------------------
| /Q             || Do not prompt for confirmation of settings
|}

After installation, a default config file called config.lua will be installed at the directory defined by /CONFIG. For further configuration of LuaRocks paths, see the [Config file format](config_file_format.md). For more information on the structure of rocks trees see [rocks repositories](rocks_repositories.md).

# Making a self-contained installation 

Another option is to install LuaRocks in a self-contained manner. This
is an interesting alternative when shipping an application which uses
third-party modules. Bundling them as rocks reduces maintenance overhead
and allows the user to perform updates.

In this scenario, it is not desired to have the user's (or the system's)
configuration affect the self-contained LuaRocks install, in case the 
user or the system also have different LuaRocks installations. For this
reason, the INSTALL.BAT script allows to hardcode the location of a
configuration file. For example, the compilation process of a package
bundling LuaRocks could do something like this:

```
SET PREFIX=C:\mypackage
 INSTALL /P %PREFIX% /CONFIG %PREFIX%\luarocks
```

The copy of LuaRocks installed in C:\mypackage will ignore
customization schemes such as the %LUAROCKS_CONFIG% environment variable
and will only use C:\mypackage\luarocks\config.lua.

An interesting option in those cases is for the application to provide
in its configuration file an URL for their own rocks repository, so they
can have control over updates to be performed. Continuing the previous
example, luarocks\config.lua could contain something like this:

```
repositories = {
    "http://www.example.com/rocks/"
 }
```

# Picking the Lua interpreter 

LuaRocks can use its own Lua interpreter provided by the Lua for WIndows project,
and will do so by default if it fails to find your Lua installation
automatically. If you want to use your own interpreter, which is not on the system path, 
you can pass its path using the /LUA variable (or /BIN, /LIB and /INC explicitly, if 
you have a custom directory structure).

When looking for an interpreter, it will also try to figure out the name of 
the Lua binary (lua.exe, lua5.1.exe). This is set in the `lua_interpreter`
variable in the configuration file. If you want to use an alternative name to the
interpreter, you can set that variable in your configuration file directly.

An important element is the runtime libraries used by the interpreter, as LuaRocks must
compile additional rocks installed with the same runtime as the interpreter. To do this
LuaRocks will analyse the executable found.

# Next steps 

Once LuaRocks is installed, learn more about [using LuaRocks](using_luarocks.md).


