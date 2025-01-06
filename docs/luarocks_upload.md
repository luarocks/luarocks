# luarocks upload

Upload a rockspec to the public rocks repository.

## Usage

`luarocks upload [--skip-pack] [--api-key=<key>] [--force] <rockspec>`

Packs a source rock file (`.src.rock`) using a rockspec and uploads it
and the rockspec to the public rocks repository.

To access the server, an API key is required. It is passed using `--api-key`
option and can be issued at the [LuaRocks site](https://luarocks.org/) on
the "Setting" page after logging in.

If `--skip-pack` is passed, the source rock is not packed and only the rockspec
is uploaded.

If `--force` is passed, existing files will be overwritten if the same version
of the package already exists.

## Example

```
luarocks upload my-rock-0.1.0-1.rockspec --api-key=<REDACTED>
```
