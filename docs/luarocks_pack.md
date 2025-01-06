# luarocks pack

Create a rock, packing sources or binaries.

## Usage

`luarocks pack {<rockspec> | <name> [<version>]}`

Argument may be a rockspec file, for creating a source rock, or the name of an
installed package, for creating a binary rock. In the latter case, the package
version may be given as a second argument.

## Examples

```
luarocks pack luafilesystem 1.4.0
```

Assuming you have LuaFileSystem 1.4.0 installed in your local tree, this
creates in the current directory a file called
`luafilesystem-1.4.0-1.linux-x86.rock` (filename will of course vary according
to the platform), using the binary that is already installed.

```
luarocks pack copas-1.1.1-1.rockspec
```

Assuming you have `copas-1.1.1-1.rockspec` in the current directory, this
creates (also in the current directory) a file called
`copas-1.1.1-1.src.rock`, fetching sources as specified in the rockspec.

