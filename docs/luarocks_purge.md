# luarocks purge

Remove all installed rocks from a tree.

## Usage

`luarocks purge --tree=<tree> [--old-versions]`

Removes all installed rocks from a given tree. The tree must be provided
explicitly using `--tree`.

If `--old-versions` is passed, the highest version
of each rock is kept.

## Example

Deleting all rocks from local tree:

```
luarocks purge --tree=~/.luarocks
```

