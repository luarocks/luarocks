# Namespaces

The LuaRocks.org repository allows for each user to published their own
collection of rocks. Since LuaRocks 3, this concept of per-user rocks has been
integrated into the tool, in the form of **namespaces**.

What you can do with namespaces:

* Install packages using a namespace:
  * `luarocks install my_user/my_rock`
* Depend on a specific namespaced version of a rock in your rockspec:
  * `dependencies = { "my_user/my_rock > 2.0" }`

## Background

LuaRocks has always supported multiple repositories, which can be set in the
[config file](config_file_format.md) with the `rocks_servers` entry. A
repository is an address (a local directory or a remote URL) where LuaRocks
can find a `manifest-5.x` file and .rock and .rockspec files. We also call
such repository a "manifest", for short. 

The [LuaRocks.org](LuaRocks.org)(LuaRocks.org)(https://luarocks.org) website
features a root manifest at `https://luarocks.org` as well as per-user
manifests at `https://luarocks.org/manifests/<your-user-name>`. Entries in the
root manifest are operated in a first-come first-served manner, but even if
someone else has already taken a rock name, you can upload your own version of
it to your user manifest. You can refer to a per-user manifest the same way as
any other rocks server, adding to your configuration or using it with the
`--server` flag. This means that you were always able to install your own
version of a rock using a command such as `luarocks install <my-rock>
--server=https://luarocks.org/manifests/<your-user-name>`. However, you could
not specifically depend on it from another rockspec, and once installed, the
information that this rock came from a specific manifest was lost. With
namespaces, now you can!

## Using namespaces

All `luarocks` commands that accept a rock name as command line argument can
now take a namespaced variant:

```
luarocks install my_user/my_rock
```

LuaRocks will take your `rocks_trees` configuration and search for namespaced
manifests on each entry: for example, given the default server
`https://luarocks.org` it will look in
`https://luarocks.org/manifests/my_user`.

When installing, LuaRocks will internally store the information that this copy
of `my_rock` came from the `my_user` namespace, so it will be able to use that
information when another rockspec specifically asks for `my_user/my_rock` in
its dependencies. (The namespace information is stored in a separate
`rock_namespace` metadata file, at
`lib/luarocks/rocks-5.x/my_rock/1.0-1/rock_namespace`, relative to your local
rocks tree.)

## Compatibility between non-namespaced and namespaced rocks

A namespaced package can stand for a non-namespaced one. If you have
`my_user/my_rock 1.0` installed and a rock depends on `my_rock 1.0`, the
installed rock will satisfy the dependency.

The opposite is not true: if you have `my_rock 1.0` installed but that did not
come from a `my_user` namespace, it will not satisfy a dependency for
`my_user/my_rock`.

## Current limitations

You cannot have two rocks with the same name and version but different
namespaces installed at the same time in the same local rocks tree.
