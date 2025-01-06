# luarocks unpack

Unpack the contents of a rock.

## Usage

`luarocks unpack [--force] {<rock> | <rockspec> | <name> [<version>]}`

Unpacks the contents of a rock in a newly created directory under the current
directory. Argument may be a rock file, a rockspec file, or the name of a
rock/rockspec in a remote repository.

If `--force` is passed, files are unpacked even if the output directory
already exists.

When a rock is given, LuaRocks creates a directory and extracts the contents
of a rock inside it. If it is a `.src.rock` file, it also extracts the
sources, and copies the rock's rockspec to the root of the sources directory,
so that you can run [luarocks make](luarocks_make.md).

When a rockspec is given, LuaRocks creates a directory and then fetches and
extracts the sources for the module inside it. It also copies the rockspec to
the root of the sources directory.

When a binary rock is given, it just extracts the contents of the rock in the
created directory for further inspection. To fetch the sources, you can run
`luarocks unpack` again on the rockspec file that will be extracted from the
binary rock.

When a name (and optionally a version) is given, LuaRocks tries to download a
source rock or a rockspec from remote repositories, and then proceeds as if
the obtained file was provided locally.

## Examples

```
luarocks unpack luafilesystem 1.4.0
```

This fetches `luafilesystem-1.4.0-1.src.rock` from the remote repository and
creates in the current directory a directory called `luafilesystem-1.4.0-1`
with the contents of the rock, including the LuaFileSystem sources unpacked.
You will then be able to go into the
`luafilesystem-1.4.0-1/luafilesystem-1.4.0` directory and run [luarocks
make](luarocks_make.md).

```
luarocks unpack copas-1.1.1-1.rockspec
```

Assuming you have `copas-1.1.1-1.rockspec` in the current directory, this
creates in the current directory a directory called `copas-1.1.1-1` with the
rockspec and the Copas sources unpacked. You will then be able to go into the
`copas-1.1.1-1/copas-1.1.1` directory and run [luarocks
make](luarocks_make.md).

While the extracted directory names may look repetitive, note that the first
directory is a directory in a LuaRocks "name-version-revision" format, and the
second directory is the directory contained inside the sources archives, which
may be in any format, and in some cases may not even exist.

