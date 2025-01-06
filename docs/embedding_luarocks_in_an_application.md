# Embedding LuaRocks in an application

You can use LuaRocks bundled inside your application, for example, to install
application-specific extension modules. Packaging those extensions or plugins
as rocks reduces maintenance overhead and allows the user to perform updates.

In this scenario, it is not desirable to have the application-specific
LuaRocks and any other copy of LuaRocks installed by the user (or other
applications!) to interfere with each other. For this reason, the `configure` 
script allows hardcoding the location of a configuration file. For example,
the compilation process of a package bundling LuaRocks could do something like
this:

```bash
export PREFIX=$HOME/my-app/
./configure --prefix=$PREFIX --sysconfdir=$PREFIX/luarocks --force-config
```

The copy of LuaRocks installed in `$HOME/my-app/` will ignore customization
schemes such as the `$LUAROCKS_CONFIG` environment variable and will only use
`$HOME/my-app/luarocks/config-5.x.lua`.

An interesting option in those cases is for the application to provide in its
configuration file an URL for their own rocks repository, so they can have
control over updates to be performed. Continuing the previous example, the
config-5.x.lua file could contain something like this:

```lua
 rocks_servers = {
    "http://www.example.com/my-app-plugins/rocks/"
 }
```

This way the bundled copy of LuaRocks will download rocks from your app's
plugins and not the https://luarocks.org server (note that the user would
still be able to override it explicitly using the `--server` flag).
