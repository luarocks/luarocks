# luarocks install

Install a rock.

## Usage

`luarocks install [--keep] [--only-deps] {<rock> | <name> [<version>]}`

Argument may be the name of a rock to be fetched from a server, with optional
version, or the direct URL or filename of a rockspec. In case of more than one
rock matching the request, the `install` command favors binary rocks.

Unless `--keep` is passed, other versions of the rock are removed after
installing the new one.

If `--only-deps` is passed, the rock itself is not installed, but its
dependencies are.

## Examples

Installing a rock:

```
luarocks install luasocket
```

Installing a specific version of a rock:

```
luarocks install luasocket 3.0rc1
```

Installing a rock ignoring its dependencies:

```
luarocks install busted --deps-mode=none
```
