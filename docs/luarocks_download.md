# luarocks download

Download a specific rock or rockspec file from a rocks server.

## Usage

`luarocks download [--all] [--arch=<arch> | --source | --rockspec] [<name> [<version>]]`

If `--all` is passed, all matching files are downloaded, and `<name>` argument
becomes optional. `--arch`, `--source` and `--rockspec` options select file
type.

## Example

Download rockspec for the latest version of a rock:

```
luarocks download --rockspec lpeg
```
