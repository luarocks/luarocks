# luarocks doc

Show documentation for an installed rock.

## Usage

`luarocks doc [--home] [--list] <name> [<version>]`

Attempts to open documentation for an installed rock using a number
of heuristics.

If `--home` is passed, opens the home page of the project.

If `--list` is passed, documentation files bundled with the rock
are listed but not opened.

## Example

```
luarocks doc luasocket
```
