# Rock file format

This page describes the .rock file format used by LuaRocks.

Note that there are different [types of rocks](types_of_rocks.md). 

## Filenames

* .rock and .rockspec filenames must be all-lowercase
* Rock names must follow the format "$NAME-$VERSION-$REVISION.$PLATFORM.rock", where:

 * $NAME is an arbitrary name (matchable via `"[a-z0-9_-]+"`)
 * $VERSION is a version number parseable by LuaRocks (e.g. "1.0", "2.1beta1", "scm" for git-HEAD/svn-master rockspecs)
 * $REVISION is the rockspec revision number, a positive integer
 * $PLATFORM must follow the format "$OS-$ARCH", where:

    * $OS is an operating system identifier known by LuaRocks
    * $ARCH is a hardware architecture identifier known by LuaRocks

## Source rocks

A source rock must contain at its root the rockspec file. For a rock called `myrock-1.0-1.src.rock` it would be called:

* `myrock-1.0-1.rockspec` - the [rockspec file](Rockspec format) in the archive root

Additionally, it must contain the sources:

* If the `source.url` field is specified using a file download protocol-type URL (`http://`, `https://`, `file://` and so on) pointing to the source archive (or source file in case of a single-file rock), the rock should contain the product of downloading this URL. 
  * For example, a source rock may contain two files: `myrock-1.0-1.rockspec` and `myrock-1.0.tar.gz`
* If the `source.url` field is specified using a Source Control Manager (SCM) protocol-type URL (`git://`, `hg://`, `svn://` and so on), the rock should contain the corresponding checked-out sources. The SCM metadata (e.g. the `.git` directory) does not need to be present. (Note: This is not specific to "scm" rocks that point to in-development repositories; a stable-version rockspec may use a SCM-based URL and an SCM tag with `source.tag` in the rockspec to point to a release version).
  * For example, a source rock may contain at the root the rockspec `myrock-1.0-1.rockspec` and a directory `myrock` that would be the result of `git clone https://github.com/example/myrock`

## Binary rocks

A binary rock must contain at its root two files. For a rock called `myrock-1.0-1.linux-x86.rock` they would be called:

* `myrock-1.0-1.rockspec` - the [rockspec file](Rockspec-format) in the archive root
* `rock_manifest` - a [rock manifest file](Rock-manifest-file-format)

These standard directories are handled specially:

* `lib/` - a directory containing binary modules (the contents of this directory are files that go into `$PREFIX/lib/lua/5.x/` in a vanilla Lua installation on Unix). The directory structure inside this directory is replicated when installing.
* `lua/` - a directory containing Lua modules (the contents of this directory are files that go into `$PREFIX/share/lua/5.x/` in a vanilla Lua installation on Unix). The directory structure inside this directory is replicated when installing.
* `bin/` - a directory containing executable Lua scripts (the contents of this directory are files that go into `$PREFIX/bin/` in a vanilla Lua installation on Unix) 
* `doc/` or `docs/` - documentation files - if present, their contents are listed when running `luarocks doc`. The directory structure inside this directory is replicated when installing.

Any additional directories in the .rock file are copied verbatim (including subdirectories) to `$ROCK_TREE/lib/luarocks/rocks-5.x/myrock/1.0-1/` (common directories are `tests`, `samples`, `examples`, etc.

### Pure-Lua rocks

Pure-Lua rocks are identical to binary rocks, except that they don't have a `lib/` directory containing binary modules. When a rock contains only `lua/` files and no `lib/` files, it automatically gains the `.all.rock` file extension. If the rock is platform-specific, the packager may rename the file to the proper platform, or specify the list of supported platforms in the `supported_platforms` table of the rockspec.
