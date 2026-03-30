# luarocks-admin make manifest

Compile a manifest file for a repository.

## Usage

`luarocks-admin make-manifest [--local-tree] [<repository>]`

`<repository>`, if given, is a local repository pathname. If no argument is
given, rebuilds the manifest for the local repository of installed packages.

This command is used to update the [manifest file](manifest_file_format.md) in
a directory containing rocks. By publishing a directory in a web server
containing rocks and a manifest file, one creates a remote repository -
LuaRocks clients can then configure their [configuration files](config_file_format.md) to search this repository.

If `--local-tree` is passed, versioned versions of the manifest file are not
created. Use this when rebuilding the manifest of a local rocks tree.

## Example

Suppose you wrote a rockspec for your module called "LuaSomething" and you
want to publish a LuaRocks repository in your site. (Normally, you don't need
to do this, just upload your rockspec to the public rocks repository, so that
LuaRocks users can access your module without further configuration. But let's
proceed with the example.) Your module, LuaSomething, is now installed in your
local repository: you can find it at `~/.luarocks/rocks/luasomething/1.0-1/`.
To prepare a public repository, let's first pack your new rock:

```
luarocks pack luasomething
```

If LuaSomething is a pure-Lua module, this will generate
`luasomething-1.0-1.all.rock` - this is a portable rock. If it contains C
code, it generated a non-portable rock, such as
`luasomething-1.0-1.linux-x86.rock` (in the Linux case specifically, it's
probably not a good idea to publish binary rocks as they most likely won't be
portable across Linux distributions). As an alternative, run [luarocks
pack](luarocks_pack.md) on the rockspec, to create a source rock:

```
luarocks pack ~/.luarocks/rocks/luasomething/1.0-1/luasomething-1.0-1.rockspec
```

This will create `luasomething-1.0-1.src.rock`. 

Now, create a directory that we'll use to create your public repository, and copy the files you want to publish.

```
mkdir ~/myrocksrepo
cp luasomething-1.0-1.src.rock ~/myrocksrepo
cp ~/.luarocks/rocks/luasomething/1.0-1/luasomething-1.0-1.rockspec ~/myrocksrepo
```

Perhaps you may have also a Windows build of your rock, packed with [luarocks
pack](luarocks_pack.md) on a Windows machine:

```
cp luasomething-1.0-1.win32-x86.rock ~/myrocksrepo
```

Now create a manifest file for this directory:

```
luarocks-admin make-manifest ~/myrocksrepo
```

And we're done: you can now just copy these files and the generated manifest
to a public directory in a web server and your users will be able to use your
rock by adding the URL you published the files at to their "repositories"
array in their LuaRocks configuration file.
