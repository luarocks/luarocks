# Pinning versions with a lock file

Pinning dependency versions is a way to get more predictable builds. As
explained in [this
page](https://before-you-ship.18f.gov/infrastructure/pinning-dependencies/):

> The practice of “pinning dependencies” refers to making explicit the
versions of software your application depends on (defining the dependencies of
new software libraries is outside the scope of this document). Dependency
pinning takes different forms in different frameworks, but the high-level idea
is to “freeze” dependencies so that deployments are repeatable. Without this,
we run the risk of executing different software whenever servers are restaged,
a new team-member joins the project, or between development and production
environments. 

## Pinning dependencies in LuaRocks

To pin dependencies in LuaRocks, you build a package as usual, using `luarocks
build` or `luarocks make`, and add the `--pin` option. This will build the
package and its dependencies, and will also create a `luarocks.lock` file in
the current directory. This is a text file containing the names and versions
of all dependencies (and its dependencies, recursively) that were installed,
with the exact versions used when building.

## Using pinned dependencies in LuaRocks

When building a package with `luarocks build`, `luarocks make` (or via
`luarocks install` if there is not prebuilt binary package), *without* using
`--pin`, if the current directory contains a `luarocks.lock` file, it is used
as the authoritative source for exact version of all dependencies, both
immediate and recursively loaded dependencies. For each dependency that is
recursively scanned, LuaRocks will attempt to use the version in the
`luarocks.lock` file, ignoring the version constraints in the rockspec.

When building a package using a lock file, `luarocks.lock` is copied to the
package's metadata directory (e.g.
`/usr/local/luarocks/rocks/5.3/name/version/luarocks.lock`) — if you later
pack it as a binary rock with `luarocks pack`, the lock file will be packaged
inside the rock, and will be used when that binary rock is installed with
`luarocks install`.

## Updating pinned dependencies

Building a package again with the `--pin` flag ignores any existing
`luarocks.lock` file and recreates this file, by scanning dependency based on
the dependency constraints specified in the rockspec.

It is also possible to edit the `luarocks.lock` by hand, of course, but there
are no checks: if the versions you set for the various dependencies are not
compatible with each other, LuaRocks won't be able to do anything about it and
will blindly follow what is set on the `luarocks.lock` file.

