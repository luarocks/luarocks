# luarocks new_version

Auto-write a rockspec for a new version of a rock.

## Usage

`luarocks new_version [--tag=<tag>] [<package>|<rockspec>] [<new_version>] [<new_url>]`

Creates a rockspec for a new version of a rock based on data from an existing
rockspec.

If a package name is given, it downloads the latest rockspec from the public
rocks server. If a rockspec URL or path is given, it uses it instead. If no
argument is given, it looks for a rockspec same way the [luarocks
make](luarocks_make.md) command does.

New version of the rockspec can be specified by passing it as the second
argument or by using `--tag` option: the tag will be used as version, with
leading "v" removed.

New URL (value of `source.url` rockspec field) can be passed as the third
argument. If it's not passed explicitly it will be inferred from the old URL
by replacing occurrences of the old version in it with the new one. If new tag
(value of `source.tag`) is not set explicitly using `--tag`, it is updated in
the same way.

## Example

Creating a rockspec for version `0.2.0` from an scm rockspec in current
directory, with new tag `v0.2.0`:

```
luarocks new_version --tag=v0.2.0
```

This creates a rockspec called `my-rock-0.2.0-1.rockspec` in current directory.

