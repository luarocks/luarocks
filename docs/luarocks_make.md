# luarocks make

Compile package in current directory using a rockspec.

## Usage

`luarocks make [--pack-binary-rock] [<rockspec>]`

Builds sources in the current directory, but unlike [luarocks
build](luarocks_build.md), it does not fetch sources, etc., assuming
everything is available in the current directory. After the build is complete,
it also installs the rock.

If no argument is given, it looks for a rockspec in the current directory and
in `./rockspec` and `./rockspecs` subdirectories. Of all the rockspecs the one
with the highest version is used. If rockspecs for more than one rock are
found, you must specify which one to use through the command-line.

If `--pack-binary-rock` is passed, the rock is not installed; instead, a
`.rock` file with the contents of compilation is produced in the current
directory.

## Example

```
luarocks make
```
