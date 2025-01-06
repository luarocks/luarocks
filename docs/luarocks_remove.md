# luarocks remove

Uninstall a rock.

## Usage

`luarocks remove [--force|--force-fast] <name> [<version>]`

`<name>` is the name of a rock to be uninstalled. If a `<version>` is not
given, try to remove all versions at once. Will only perform the removal if it
does not break dependencies.

To override this check and force the removal, use `--force`.

To perform a forced removal without looking for broken dependencies,
use `--force-fast`.

## Example

```
luarocks remove --force luafilesystem 1.3.0
```
