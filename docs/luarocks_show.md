# luarocks show

Shows information about an installed rock.

## Usage

`luarocks show <name> [<version>]`

`<name>` is an installed package name.
Without any flags, show all module information.
With these flags, return only the desired information:

* `--home` - home page of project
* `--modules` - all modules provided by this package as used by `require()`
* `--deps` - packages this package depends on, including indirect dependencies
* `--rockspec` - the full path of the rockspec file
* `--mversion` - the package version
* `--rock-tree` - local tree where rock is installed
* `--rock-dir` - data directory of the installed rock

## Example

```
luarocks show luasocket
```
