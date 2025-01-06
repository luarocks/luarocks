# Integrating distro modules with LuaRocks

This is documentation on strategies to integrate OS-installed modules (e.g.
packages such as `luafilesystem` and `lpeg` provided by Linux distros) with
existing versions of LuaRocks.

This page will list two approaches: the minimal one, and a more complete one
that extends the first one.

## Assumptions

* The examples below use Lua 5.3 — just change "5.3" to "5.1" or "5.2" and the
  same applies.
* Distro-installed modules live at standard Lua locations under `/usr`, such
  as `/usr/lib/lua/5.3/lfs.so`

## The bare minimum approach

This is the _minimum_ that should be added to distro module packages so that
they visible as dependencies by LuaRocks:

### The main manifest file

For LuaRocks to be able to find any OS-installed modules, there needs to be an
index file called `manifest` at `/usr/lib/luarocks/rocks-5.3/`.

This file should be generated running:

```
luarocks-admin make-manifest --local-tree --tree=/usr
```

This should be run as a post-install action after installing any module via
the distro. This file is the LuaRocks "index" and should be kept up-to-date or
else LuaRocks doesn't know about the installed modules.

### Rock metadata necessary to build the main manifest

For the above command to work, there has to be a directory tree for each rock
and version, containing, at the bare minimum, a `rock_manifest` file. The
structure looks like this:

`/usr/lib/luarocks/rocks-$LUA_VERSION/$ROCK_NAME/$ROCK_VERSION-$ROCK_REVISION/`

* $LUA_VERSION with with a dot: "5.3"

* $ROCK_NAME should match the name used in the luarocks.org repository — in other words, `luafilesystem` has to be called `luafilesystem`, not `lfs`. LuaRocks checks dependencies by rock name, not by individual module name.

* $ROCK_VERSION usually matches upstream, so that's not an issue.

* $ROCK_REVISION can always be 0 for our purposes here.

Examples:

* /usr/lib/luarocks/rocks-5.3/lpeg/1.0.0-0/
* /usr/lib/luarocks/rocks-5.3/luafilesystem/1.6.0-0/
* /usr/lib/luarocks/rocks-5.3/lua-cjson/2.1.0-0/

### The rock_manifest file

Inside the version directory for a rock there must be a `rock_manifest` file.
The minimal contents of `rock_manifest` to make `luarocks-admin` not fail is
simply:

```lua
rock_manifest = {}
```

This means that in the above examples, we'd have several identical one-liner files:

* /usr/lib/luarocks/rocks-5.3/lpeg/1.0.0-0/rock_manifest
* /usr/lib/luarocks/rocks-5.3/luafilesystem/1.6.0-0/rock_manifest
* /usr/lib/luarocks/rocks-5.3/lua-cjson/2.1.0-0/rock_manifest

### Necessary LuaRocks configuration

With those empty manifests, the post-install operation mentioned above works
and a later `luarocks install` will the existence of the "rocks" in /usr,
given the following configuration in `/etc/luarocks/config-5.3.lua`:

```
rocks_trees = {
   { name = "user", root = home.."/.luarocks" },
   { name = "distro-modules", root = "/usr" },
   { name = "system", root = "/usr/local" },
}
deps_mode = "all"
```

It's important that the "system" tree is the last entry: it is the one used
for system-wide installation of rocks using LuaRocks (when `sudo luarocks` is
used). The "distro-modules" tree should never be used directly by the user.

For more info on the deps_mode flag, see the [Dependency
modes](dependencies.md#dependency-modes) documentation.

### Caveats

*Error messages*: Running with such bare minimum setup will resolve
dependencies, but running the post-install operation above will output error
messages when running, such as...

```
Tree inconsistency detected: luafilesystem 1.6.0-0 has no rockspec. Could not load rockspec file /usr/lib/luarocks/rocks-5.3/luafilesystem/1.6.0-0/luafilesystem-1.6.0-0.rockspec (/usr/lib/luarocks/rocks-5.3/luafilesystem/1.6.0-0/luafilesystem-1.6.0-0.rockspec: No such file or directory)"
```

...for each entry under `/usr/lib/luarocks/rocks-5.3` (for our purposes, these
can be simply ignored and silenced away with `&> /dev/null`).

*Failed commands*: this minimal tree will work for solving dependencies, but
not for much else. In particular, `luarocks list --tree=/usr` will work, but
`luarocks show lpeg --tree=/user` will not, complaining that it can't find a
rockspec.

## A more complete approach

A more complete approach to make commands such as `luarocks show` to work
would entail two steps: adding proper contents to `rock_manifest` and
including a rockspec file for each module.

### A complete rock_manifest

A workable version of `rock_manifest` with contents would look like this:

```
rock_manifest = {
   lib = {
      ["lpeg.so"] = "136a74c6e472c36a65449184e1820a31"
   },
   ["lpeg-1.0.0-0.rockspec"] = "4933a611af43404761002ee139c393e8",
   lua = {
      ["re.lua"] = "5f09bb0129b09b6a8e8c1db1b206b1ca"
   }
}
```

The entries under `lib` are the files installed by the package at `/usr/lib/5.3`.
The entries under `lua` are the files installed by the package at `/usr/share/5.3`.
The rockspec key is the rockspec file to be stored alongside the `rock_manifest` file.
The values to these entries are MD5 sums to the files in question.

### Including a rockspec file

For `luarocks show` to display metadata properly, a rockspec file must exist.
It should be named according to the pattern
`$ROCK_NAME-$ROCK_VERSION-$ROCK_REVISION.rockspec` (in all lowercase).
Continuing the examples above:

* /usr/lib/luarocks/rocks-5.3/lpeg/1.0.0-0/lpeg-1.0.0-0.rockspec
* /usr/lib/luarocks/rocks-5.3/luafilesystem/1.6.0-0/luafilesystem-1.6.0-0.rockspec
* /usr/lib/luarocks/rocks-5.3/lua-cjson/2.1.0-0/lua-cjson-2.1.0-0.rockspec

For simplicity, I would recommend just copying over the appropriate rockspec
file from [luarocks.org](http://luarocks.org) and bundling them in the package
metadata. For completeness, this is how the one for LPeg 1.0 looks like:

```
package = "LPeg"
version = "1.0.0-1"
source = {
   url = "http://www.inf.puc-rio.br/~roberto/lpeg/lpeg-1.0.0.tar.gz",
   md5 = "0aec64ccd13996202ad0c099e2877ece",
}
description = {
   summary = "Parsing Expression Grammars For Lua",
   detailed = [[
      LPeg is a new pattern-matching library for Lua, based on Parsing
      Expression Grammars (PEGs). The nice thing about PEGs is that it
      has a formal basis (instead of being an ad-hoc set of features),
      allows an efficient and simple implementation, and does most things
      we expect from a pattern-matching library (and more, as we can
      define entire grammars).
   ]],
   homepage = "http://www.inf.puc-rio.br/~roberto/lpeg.html",
   maintainer = "Gary V. Vaughan <gary@vaughan.pe>",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      lpeg = {
         "lpcap.c", "lpcode.c", "lpprint.c", "lptree.c", "lpvm.c"
      },
      re = "re.lua"
   }
}
```
