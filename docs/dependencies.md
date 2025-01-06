# Dependencies

LuaRocks handles dependencies on Lua modules — rocks can specify other rocks
it depends on, and attempts to fulfill those dependencies at install time. A
rock will only be installed if all its dependencies can be fulfilled.

LuaRocks also supports verification of dependencies on external libraries. A
rock can specify an external package it depends on (for example, a C library),
and give to LuaRocks hints on how to detect if it is present, typically as C
header or library filenames. LuaRocks then looks for these files in a
pre-configured search path and, if found, assumes the dependency is fulfilled.
If not found, an error message is reported and the user can then install the
missing external dependency (using the tools provided by their operating
system) or inform LuaRocks of the location of the external dependency in case
it was installed and LuaRocks failed to find it.

Dependencies of a rock are specified in its [rockspec](rockspec_format.md)
file. See the complete specification of the dependency syntax in the [Rockspec
format](rockspec_format.md) page and examples in rockspec files of the [public
rocks server](http://luarocks.org/).

# Dependency modes 

Since 2.0.12, the LuaRocks command-line tool supports different "dependency
modes". These are useful to specify how it should behave on the presence of
multiple rocks trees specified in the [config file](config_file_format.md):

* `one`
* `all`
* `order`
* `none`

This can be set through the configuration file, using the string variable
deps_mode (example: `deps_mode="order"`) or through the command-line, using the
`--deps-mode` flag (example: `--deps-mode=order`).

## one 

This is the default behavior. LuaRocks only takes **one** rocks tree into
account when checking dependencies. For example, if you have two rocks trees
configured (`rocks_trees={home.."/.luarocks", "/usr"}`) and you try to install
a rock in `$HOME/.luarocks`, it will check that all required dependencies are
installed _in that tree_. If the dependency rock is already installed under
`/usr`, it will ignore that copy.

This is a cautious behavior because it ensures that a rock and all its
dependencies are installed under the same tree. So, if another user modifies
the other tree, there's no risk that the rock installed in your home tree
might stop working.

## all 

LuaRocks scans **all** configured rocks trees to search for dependencies. If
the required rock for a dependency is available in _any_ tree, it will
consider that dependency fulfilled, and will not install that again.

However, note for example that if you install a rock in /usr and its
dependency was installed in your $HOME tree, the installed rock will work for
your user account (which has access to the /usr tree and your home tree), but
will probably not work for other users, if they don't have a compatible
dependency installed in their own home trees.

## order 

LuaRocks uses the **order** of the list of rocks trees to determine if a rocks
tree should be used as a valid provider of dependencies or not. LuaRocks will
only use rocks from either the tree it is installing to, or trees that appear
**below** the rock that's in use in the rocks_trees array. So, if your
rocks_trees array looks like `{home.."/.luarocks", "/usr/local", "/usr"}`,
installing a rock under your $HOME directory will accept dependencies from any
of the three trees. Installing into `/usr/local` will use dependencies from `/usr`
but not from the `$HOME` directory. Installing into `/usr` will use rocks from
that tree only.

So, by carefully ordering your array of rocks trees in the configuration file,
you can use the same configuration file for both your administrator account
and your regular user account.

Note, however, that like in the "all" mode, an administrator can break a rock
you installed in your home account by removing a dependency rock from the
global tree.

## none 

LuaRocks does not use any tree, or install any dependencies. This means, of
course, that installed rocks may be installed with missing dependencies and
may simply not work. This mode is not recommended for general use, but it is
useful in some specific scenarios (incorrect dependencies, batch
recompilation, etc.)

This is equivalent to the old `--nodeps` option.
