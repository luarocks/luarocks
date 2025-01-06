# luarocks list

Lists currently installed rocks.

## Usage

`luarocks list [--outdated] [--porcelain] [<query>] [<version>]`

`<query>` is a substring of a rock name to filter by. When no arguments are
supplied, a list of all rocks you have installed is returned.

If `--outdated` is passed, only rocks for which there is a higher version
available in the rocks server are listed.

If `--porcelain` is passed, machine-friendly output is produced.

The `list` command queries the local repository (the rocks you have
installed). To query remote repositories (the rocks available for download at
the LuaRocks server), use [luarocks search](luarocks_search.md).

## Example

List all installed rocks:

```
luarocks list
```
