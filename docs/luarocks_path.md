# luarocks path

Return the currently configured package path.

## Usage

`luarocks path [--append] [--bin] [--lr-path | --lr-cpath | --lr-bin]`

Prints package paths for this installation of Luarocks formatted as a shell
script. The script prepends these values to default system ones
(`package.path` and `package.cpath`) and updates `$LUA_PATH` and `$LUA_CPATH`
environment variables. On Unix systems, you may run:

```
eval $(luarocks path)
```

If `--append` is passed, LuaRocks paths are appended to system values instead
of being prepended.

If `--bin` is passed it also prints path to the directories where
command-line scripts provided by rocks are located, prepending it to
`$PATH` (or appending if `--append` is used).

`--lr-path`, `--lr-cpath`, and `--lr-bin` flags print just corresponding
paths, without systems values and not formatted as a shell script.

## Example

```
luarocks path
```
