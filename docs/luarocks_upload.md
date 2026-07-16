# luarocks upload

Upload a rockspec to the public rocks repository.

## Usage

`luarocks upload [--skip-pack] [--api-key=<key>] [--force] [--dry-run] <rockspec> [<src.rock>]`

Packs a source rock file (`.src.rock`) using a rockspec and

Uploads a rockspec and a source rock file (`.src.rock`) to the public rocks
repository. If the `.src.rock` file is not given, the command generates the
`.src.rock` file from the rockspec by itself.

To access the server, an API key is required. It is passed using `--api-key`
option and can be issued at the [LuaRocks site](https://luarocks.org/) on
the "Setting" page after logging in.

If `--skip-pack` is passed, the source rock is not packed and only the rockspec
is uploaded.

If `--force` is passed, existing files will be overwritten if the same version
of the package already exists.

If `--dry-run` is passed, the rockspec is validated, the source rock is packed
(unless `--skip-pack`), and the server is checked for conflicts, but no files
are uploaded.

## Example

```
luarocks upload my-rock-0.1.0-1.rockspec --api-key=<REDACTED>
```
