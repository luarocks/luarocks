# Rocks repositories

For normal use, rocks repositories are manipulated by the `luarocks`
command-line tool. LuaRocks fetches rocks from one kind of repository -- rocks
servers -- and installs them into another kind of repository -- rocks trees.

Generally speaking, a rocks repository is a directory containing rocks and/or
rockspecs, and a manifest file which catalogs the rocks contained therein. 
Rocks servers may contain [packed rocks](types_of_rocks.md) and rockspecs, and
may be located in remote (HTTP or FTP) URLs or paths in the local filesystem.
Rocks trees can contain only [unpacked](types_of_rocks.md) (installed) rocks,
and are always local.

LuaRocks can be configured to use multiple rocks trees and multiple rocks
servers. See the [Config file format](config_file_format.md) for details and
the reference for the [luarocks](luarocks.md) command-line tool for details.

Publishing a repository as a rocks server consists of making a directory
containing rocks and a manifest file available online. A manifest file can be
created using the make-manifest command of the `luarocks-admin` command-line
tool, included in LuaRocks. For the rocks tree, the manifest file is updated
automatically by LuaRocks.

# Rocktree structure 

A rocks tree has this (default) layout;

```
{base}                (base rocks tree directory)
  ├── bin              (deployment of command line scripts)
  ├── lib
  │    ├── luarocks
  │    │    └── rocks  (contains manifest and sub-dirs with rocks)
  │    │
  │    └── lua
  │         └── 5.1    (deployment of binary modules)
  │
  └── share
       └── lua
            └── 5.1    (deployment of Lua modules)
```

Whenever LuaRocks installs a rock it will install them (the executable parts)
in the deployment directories. These directories should be included in your
system path, `LUA_PATH`, and `LUA_CPATH` to be able to
`require` the modules from your own scripts or use the command line
scripts from a prompt. Other included elements (see `copy_directories`
in rockspec), including the manifest and rockspecs, will be stored in the
`base/lib/luarocks/rocks`.

When multiple versions of the same rock are being installed, the older ones in
the deployment directories will be renamed to a name including the version.
The `luarocks.loader` module will be able to load the proper version of
the modules despite the changed names.
