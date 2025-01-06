# luarocks build

Build/compile and install a rock.

## Usage

`luarocks build [--pack-binary-rock] {<rockspec> | <rock> | <name> [<version>]}`

Builds and installs a rock, compiling its C parts if any. Argument may be a
rockspec file, a source rock file or the name of a rock to be fetched from a
repository, in which case a version may be passed as well. In case of more
than one rock matching the request, the `build` command favors source rocks.

If `--pack-binary-rock` is passed, the rock is not installed; instead, a
`.rock` file with the contents of compilation is produced in the current
directory.

## Example

```
luarocks build luasocket
```
