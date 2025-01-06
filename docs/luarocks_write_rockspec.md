# luarocks write_rockspec

Write a template for a rockspec file.

## Usage

`[--output=<file>] [...] [<name>] [<version>] [<url>|<path>]`

This commands creates an initial version of a rockspec for a rock
based on name, version, and location of its sources. The resulting
rockspec is just a template: several fields, such as `dependencies`,
have to be filled by hand.

If only two arguments are given, the first one is considered the name and the
second one is the location.
If only one argument is given, it must be the location.
If no arguments are given, current directory is used as location.
LuaRocks will attempt to infer name and version if not given,
using "scm" as default version.

If location is a local directory and a Git or Mercurial repository,
source URL will be inferred from it.

Resulting rockspec is created in current directory, with file name
based on rock name and version. Output location can be changed using `--output` option.

Several fields of the rockspec can be set explicitly:

* `--license=<license>` sets license name, such as `MIT/X11` (by default inferred
  from `COPYING`, `LICENSE`, or `MIT-LICENSE.txt` files, if they exist).
* `--summary=<text>` sets short description (by default inferred from
  `README.md` or `README` files, if they exist).
* `--detailed=<text>` sets detailed description (by default inferred
  from `README.md` or `README` files, if they exist).
* `--homepage` sets project home page URL (by default may be inferred from source URL).
* `--lua-version=<versions>` sets supported Lua versions. `<versions>` must be one of
  "5.1", "5.2", "5.3", "5.1,5.2", "5.2,5.3", or "5.1,5.2,5.3".
* `--rockspec-format=<version>` sets rockspec format version.
* `--tag=<tag>` sets tag to use. Will attempt to extract version number from it.
* `--lib=<lib>[,<lib>]` sets libraries that C files need to link with, filling [external_dependencies](rockspec_format.md#dependency-information) table. The argument should be a comma delimited list of names.

LuaRocks will attempt to fill `build` table of the rockspec using
[builtin build back-end](rockspec_format.md#builtin), listing files from `src`
and `lua` directories in project sources.

## Example

Creating an scm rockspec for a project hosted in a Git repository:

```
mkdir my-rock
cd my-rock
git init .
git remote add origin https://github.com/my-username/my-rock
luarocks write-rockspec
```

This creates `my-rock-scm-1.rockspec` file:

```lua
package = "my-rock"
version = "scm-1"
source = {
   url = "git+https://github.com/my-username/my-rock"
}
description = {
   homepage = "https://github.com/my-username/my-rock",
   license = "*** please specify a license ***"
}
dependencies = {}
build = {
   type = "builtin",
   modules = {}
}
```
