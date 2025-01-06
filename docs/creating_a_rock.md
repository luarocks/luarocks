# Creating a rock

So, you wrote a Lua package (containing one or more modules) and want to make
it available to users through LuaRocks. The process consists essentially of
the following steps:

* Writing a rockspec file
* Publishing your code online
* Submitting a rockspec for inclusion in the rocks server

## Writing a rockspec

A rockspec file is the metadata file for your package, containing all the
information LuaRocks needs in order to fetch, build and install your package.
The [Rockspec format](rockspec_format.md) supports various kinds of build
systems, but in this tutorial we'll use LuaRocks' own built-in build system --
that's why we're listing "Writing a rockspec" as the first step. We'll use the
rockspec in place of a Makefile.

A rockspec is actually a Lua file, but it is loaded in an empty environment,
so there are no Lua functions available. A skeleton for a basic rockspec looks
can be written by hand or generated using [luarocks write_rockspec](luarocks_write_rockspec.md).
It may look like this:

```lua
package = "LuaFruits"
version = "1.0-1"
source = {
   url = "..." -- We don't have one yet
}
description = {
   summary = "An example for the LuaRocks tutorial.",
   detailed = [[
      This is an example for the LuaRocks tutorial.
      Here we would put a detailed, typically
      paragraph-long description.
   ]],
   homepage = "http://...", -- We don't have one yet
   license = "MIT/X11" -- or whatever you like
}
dependencies = {
   "lua >= 5.1, < 5.4"
   -- If you depend on other rocks, add them here
}
build = {
   -- We'll start here.
}
```

This should be saved in a file called luafruits-1.0-1.rockspec. The name must
contain lowercase versions of the "package" and "version" fields, or else
LuaRocks will complain.

There is some missing stuff in our rockspec which we will fill later, such as
the source.url and description.homepage fields. We'll add those when we upload
our sources whatever server you choose to.

Right now our focus will be on the "build" section.

### Building a module

LuaRocks supports a number of "build types": "make" for using Makefiles,
"cmake" for using CMake, etc. In this tutorial, however, we'll use its
built-in build system, called the "builtin" type.

```lua
build = {
   type = "builtin"
   -- Now we need to tell it what to build.
}
```

In the "builtin" type, we add a subtable called "modules", in which keys are
module names in Lua notation, and values indicate how to build them. This
example shows the various possibilities supported:

```lua
build = {
   type = "builtin",
   modules = {
      -- A simple module written in Lua
      apricot = "src/apricot.lua",

      -- Note the required Lua syntax when listing submodules as keys
      ["apricot.seeds"]("apricot.seeds") = "src/apricot/seeds.lua",

      -- A simple module written in C
      banana = "src/banana.c",

      -- C modules can span multiple files.
      cherry = {"src/cherry.c", "src/cherry_pie.c"},

      -- C modules also support an extended syntax, supporting
      -- cross-platform specifications of C defines, libraries and
      -- paths for external dependencies.
      date = {
         sources = {"src/date.c", "src/cali_date.c", "src/arab_date.c"},
         defines = {"MAX_DATES_PER_MEAL=50"},
         libraries = {"date"},
         incdirs = {"$(LIBDATE_INCDIR)"},
         libdirs = {"$(LIBDATE_LIBDIR)"}
      }
   }
}
```

Since modules written in Lua do not need to be compiled, LuaRocks only needs
to know where they are in your source directory tree  in order to copy them to
the proper place on installation (see the "apricot" and "apricot.seeds" in the
above example).

Similarly, for C code with no dependencies on external libraries, it suffices
to say where the sources are and LuaRocks will invoke the appropriate compiler
and linker for the platform. You can use a simple string value for single-file
modules, such as the "banana" example above or an array value for multiple
source files (as in the "cherry" example).

To make writing rocks for projects with a common directory layout even easier,
the "builtin" build type recursively copies all files and directories it finds
in a folder called "./lua" (if it exists) to the same place as other Lua
files.  It's almost as if an entry had been added to `modules` for every file
in `lua`, except that the files will only be copied - files ending in ".c"
won't be compiled.

#### Depending on other rocks

You can specify that your code depends on other rocks, so you can use modules
from other rocks in your code and have them be automatically downloaded and
installed when a user installs your rock. 

Suppose we need the modules from the "luaknife" rock, in order to cut our
fruits. But we need version later than 2.3 of luaknife, because we're using
functions that were introduced in that version. We'll add that to our
dependencies table:

```lua
dependencies = {
   "lua >= 5.1, < 5.4",
   "luaknife >= 2.3"
}
```

Note that the dependency on Lua itself is also given in that table, and that
it uses two constraints on its version at once: `>= 5.1` and `< 5.4`. When
several constraints are used like this, they all have to be satisfied.
Therefore, `lua >= 5.1, < 5.4` means that our rock supports Lua `5.1`, `5.2`,
and `5.3`, but not yet-to-be-released `5.4`. There are a few other operators
for specifying version constraints, see
[Rockspec format](rockspec_format.md#dependency-information).

#### C modules linking to external libraries

*If your code does not use third-party libraries, you may skip this subsection.*

For building C code that links to C libraries, you can use the long syntax
given in the "date" example above, in which sources are listed in the
"sources" subtable. You need to specify the libraries to be linked in the
"libraries" subtable. The library name is specified in a platform-independent
way: in the above example, `libraries={"date"}` will result in `-ldate` for
GCC on Unix and `DATE.LIB` for MSVC on Windows. (Note that if this is not
appropriate, the rockspec format allows [per-platform
overrides](platform_overrides.md).) If you need to link code that uses
libraries, you need to tell LuaRocks where to find them. You do this by adding
a new section to the rockspec:

```lua
external_dependencies = {
   LIBDATE = {
      header = "libdate.h"
   }
}
```

Adding the "external_dependencies" table will make LuaRocks search for the
external dependencies in its lookup path (on Unix the defaults are
`/usr/local` and `/usr`; on Windows, which doesn't have a standard for
development trees, you'll probably have to specify it yourself through the
[Config file format](config_file_format.md) or the [luarocks](luarocks.md) when
invoking "luarocks"). We give a hint to LuaRocks, the `libdate.h` header, so
it can test whether the development package is really there (on many Linux
distros, one needs to install "-dev" packages in order to have all headers and
libraries needed for compilation available, so header files are a good hint).
In this case, for example, it would look for `/usr/local/include/libdate.h`
and `/usr/include/libdate.h` on Unix. If you (or your users) have LibDate
installed elsewhere, it's always possible to tell LuaRocks so through the
command-line, passing for example `LIBDATE_DIR=/opt/libdate` as an argument.

When LuaRocks succeeds finding an external dependency, it creates special
variables for it which can be used in incdirs and libdirs fields. The example
above shows two such variables, `LIBDATE_INCDIR` and `LIBDATE_LIBDIR` being
use. It's important to always pass those variables: if LibDate happened to be
in the system lookup path of your compiler, compilation would succeed without
those variables, but they would fail in a user's system where they are
somewhere else, such as in the `LIBDATE_DIR=/opt/libdate` example given
earlier.

### Using LuaRocks as a build system

Now that your build section is written, you can use LuaRocks as a build system
and have it compile and install your code as a rock. Just type:

```
luarocks make
```

and it will do its thing. Like "make", it will look for the appropriate rules
file (in our case, the rockspec) in the current directory and then will
proceed to build and install the package in your rocks tree, assuming the
sources are in the current directory as well.

### Including documentation and other files

In the build section you can include arbitrary files through the
"copy_directories" table. In this table you can list directories in your rock
that will be copied to the target rocktree during installation. 

```lua
   copy_directories = { "doc", "test" }
```

A special case for these is the "doc" directory for locally installed
documentation. Documentation installed this way will be available on the
target system through

```
luarocks doc ROCKNAME
```

## Publishing your code online

Now, to complete the rockspec for public consumption we need to fill the
sources.url field. For that, we need the code to be available online. We have
two approaches for that: if you have your source code in an online repository
such as [GitHub](GitHub)(https://github.com), you may use that directly.
Alternatively, you can publish a tarball with the sources on the web.

### Method 1: using a repository such as Github

Make sure your release is tagged in your repository. Failing to use a tag will
make LuaRocks point at your latest development code, making it a "moving
target". LuaRocks users should be directed to a specific version of your code.
(If you want to make a rockspec pointing at your repository's HEAD, use "scm"
as the version number of your rockspec -- this will identify it as a rockspec
for the "unstable" version.)

In the `source.url` field, enter the URL for your repository using your SCM tool
as the protocol. For git repositories, you don't need use the .git extension.
Then, use the `source.tag` entry to specify your tag. For example, this is how
our source section would look like if we hosted LuaFruits on Github:

```lua
source = {
   url = "git://github.com/me/luafruits",
   tag = "v1.0",
}
```

To tag a release in Git, use the "git tag" command, and remember to pass the
"--tags" flag to "git push":

```
git tag v1.0
git push --tags
```

Or use GitHub's "Releases" interface.

LuaRocks also supports other source control management systems, such as CVS
(cvs://), Subversion (svn://) and Mercurial (hg://).

Don't worry about deployment complications when using this method. When you
submit a rock for inclusion in the LuaRocks repository, a .src.rock file is
generated which contains a copy of the source code, so LuaRocks users won't
need to have Git or any other such tool installed to use your rock.

### Method 2: publishing a tarball

When using a zip or tarball, by default LuaRocks expects it to contain a
top-level directory with your code. This directory should be named the same as
the tarball itself (but without the .zip or .tar.gz extension) and its
recommended that this name be the lowercase name of the package with its
version number (but without the LuaRocks revision number). If your code is
located in a different directory, please see [Rockspec
format](rockspec_format.md) for instructions. In our example, we should make a
tarball with the following contents:

```
luafruits-1.0/
luafruits-1.0/src/apricot.lua
luafruits-1.0/src/apricot/seeds.lua
luafruits-1.0/src/banana.c
luafruits-1.0/src/cherry.c
luafruits-1.0/src/cherry_pie.c
luafruits-1.0/src/date.c
luafruits-1.0/src/cali_date.c
luafruits-1.0/src/arab_date.c
```

Note that the rockspec itself doesn't need to be stored in the tarball
(actually, storing the final rockspec inside the package is a chicken-egg
problem because rockspecs can contain the source.md5 field with a checksum of
the tarball).

It's important to note that LuaRocks does not enforce the internal structure.
Our example only has a src/ subdirectory because the build rules listed above
used it (we could have done without it if we wanted to). The tarball could
contain other files as well, such as licenses and documentation. The only
convention used here is the top level directory name, and if desired this can
be overridden in the rockspec using the sources.dir field. So, now we pack our
code. On Unix, for example, that would be:

```
tar czvpf luafruits-1.0.tar.gz luafruits-1.0/
```

And now we're ready to publish the tarball online. You can upload it to any
public web server; if you need hosting space, you can use the Pages feature
from [GitHub](GitHub)(https://github.com). Your source section would then look
something like this:

```lua
source = {
   url = "http://me.github.com/luafruits/luafruits-1.0.tar.gz"
}
```

## The completed rockspec

We're ready to complete our rockspec. By now it will look like this:

```lua
package = "LuaFruits"
version = "1.0-1"
source = {
   url = "git://github.com/me/luafruits",
   tag = "v1.0",
}
description = {
   summary = "An example for the LuaRocks tutorial.",
   detailed = [[
      This is an example for the LuaRocks tutorial.
      Here we would put a detailed, typically
      paragraph-long description.
   ]],
   homepage = "http://me.github.com/luafruits",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "luaknife >= 2.3"
}
external_dependencies = {
   LIBDATE = {
      header = "libdate.h"
   }
}
build = {
   type = "builtin",
   modules = {
      apricot = "src/apricot.lua",
      ["apricot.seeds"]("apricot.seeds") = "src/apricot/seeds.lua",
      banana = "src/banana.c",
      cherry = {"src/cherry.c", "src/cherry_pie.c"},
      date = {
         sources = {"src/date.c", "src/cali_date.c", "src/arab_date.c"},
         defines = {"MAX_DATES_PER_MEAL=50"}
         libraries = {"date"},
         incdirs = {"$(LIBDATE_INCDIR)"},
         libdirs = {"$(LIBDATE_LIBDIR)"}
      }
   },
   copy_directories = { "doc", "test" }
}
```

## Submitting a rockspec for inclusion in the rocks server

### Web upload

This is the simplest step: just create an account at
https://luarocks.org/register and upload your rockspec. It will automatically
be included in the public LuaRocks repository once the mirror propagates the
change. Users of LuaRocks >= 2.2 will be able to download your package
immediately. We will usually publish both the .rockspec file and the
appropriate .rock file in the server.

### Pack command

You can also create .rock files yourself. If you run the [luarocks
pack](luarocks_pack.md) command on your rockspec, like this:

```
luarocks pack luafruits-1.0-1.rockspec
```

you will get a file called luafruits-1.0-1.src.rock, which contains the
rockspec itself and your sources. Since it contains the source code, users
won't need to use Git or whatever tool specified in source.url to fetch the
code; it's all in the rock.

If you have the rock installed in your local tree, you can also pack the
binaries you just built:

```
luarocks pack luafruits
```

(The version is optional, latest is assumed.) This will create a file with a
name such as luafruits-1.0-1.linux-x86.rock.

### Upload command

When you've verified that creating the rock works, you can upload it to the
LuaRocks server with the [luarocks upload](luarocks_upload.md) command:

```
luarocks upload luafruits-1.0-1.rockspec --api-key=<your API key>
```

You can get an API from the [settings page of your account on the LuaRocks web
site](https://luarocks.org/settings/api-keys).

## Conclusion

And we're done -- by writing a simple rules file which simply describes which
sources compose the project and which libraries they use, we actually achieved
a lot behind the scenes: LuaRocks takes care of using the right compiler for
your platform (GCC? MSVC?), passing the right flags (-fpic? -shared? -bundle
-undefined dynamic_lookup?) and checking external dependencies (/usr/lib?
/usr/local/lib? Is it really there?). Getting all these little portability
details right is not always easy to do on hand-written Makefiles, so that's
why we recommend using LuaRocks's own build system whenever possible. There
are many other features of LuaRocks we haven't covered in this tutorial
(per-platform overrides, support for command-line scripts, etc.), but this
should get you started.



