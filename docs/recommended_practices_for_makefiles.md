# Recommended practices for Makefiles

When authoring a Lua module, especially those containing C code, developers
are always faced with some build and deployment issues: where to find
libraries, where to install modules, which flags to pass when building, and so
on. Looking at the existing modules available in the web, it is clear to see
that there are no _de facto_ standards in Makefiles for Lua modules, and that
many of them are incomplete copies of one another, and many of them share the
same deficiencies. Here is a list of some of those issues we found during the
development of LuaRocks, and how to avoid them. Following the recommendations
below will improve the portability of your Makefiles and make things easier
for writing rocks, other packagers such as Linux distributions, and your
users.

# Do not ask users to edit files "by hand" 

Asking users to hand-edit things is error-prone. Even though systems like
LuaRocks support applying patches -- which is the automated equivalent of
hand-tweaking files -- this adds maintenance burden, as patches have to be
updated on each release if any change happens in the file. Always use
variables, so that they can be overridden by automated processes. Hand-tweaks
in the code can be avoided by propagating C defines from Makefiles as well.

Don't:
```
// Edit this to suit your installation
const char* bla_dir = "/usr/local/share/bla";
```

Do:

```
BLA_DIR=/usr/local/share/bla
# ...
bla.o:
        $(CC) -c bla.c -DBLA_DIR=\"$(BLA_DIR)\"
```

## Do not hardcode any paths 

This is a corollary to the above recommendation, really. Whenever you are
passing any paths, don't write them directly in Makefile rules. Always factor
them out into variables.

# Provide a nice "install" rule 

A large number of Makefiles for Lua modules ship without an "install" rule,
probably due to the long-standing lack of standard install locations for
modules that plagued the Lua world in the past. Nowadays, however, the
convention of using .../lib/lua/5.1/ for C modules and .../share/lua/5.1/ for
Lua modules (relative to the prefix where Lua is installed) is well
established, and there is no reason not to use it. To make things even easier
for your users, you can also factor out the common Lua prefix. /usr/local is a
good default, since it is also the default for the vanilla Lua tarball.

Don't:

```
# no make install rule!
```

Do:

```
LUA_DIR=/usr/local
LUA_LIBDIR=$(LUA_DIR)/lib/lua/5.1
LUA_SHAREDIR=$(LUA_DIR)/share/lua/5.1

# ...

install:
        mkdir -p $(LUA_LIBDIR)/bla
        cp bla/core.so $(LUA_LIBDIR)/bla
        mkdir -p $(LUA_SHAREDIR)/bla
        cp bla.lua $(LUA_SHAREDIR)
        cp bla/extras.lua $(LUA_SHAREDIR)/bla
```

Some packagers recommend prepending an empty `$(DESTDIR)` variable to all target
paths in your install rule, but that's not strictly necessary if your paths
are all set into variables, which can be redefined for the "make install" run,
like in the example above.

# Do not assume libraries are in the system path 

If your program uses LibPNG, adding "-lpng" to your Makefile is not enough.
Your users may have the LibPNG library somewhere else, so let them specify the
locations of both the libraries and headers. The default values you pick are
not really important, as long as they're overridable by the user, but
/usr/local is always a good choice on Unix systems as this is the first
typical "non-system path" that users may want to use.

Of course, use one library per value; don't assume all third-party libraries
can be found in the same place.

Don't:

```
gcc -o bla bla.c -lpng
```

Do:

```
LIBPNG_DIR=/usr/local
LIBPNG_INCDIR=$(LIBPNG_DIR)/include
LIBPNG_LIBDIR=$(LIBPNG_DIR)/lib

# ...
        $(CC) -o bla bla.c -lpng -L$(LIBPNG_LIBDIR) -I$(LIBPNG_INCDIR)
```

# Avoid compiler assumptions 

Even if your code only compiles in GCC and is Unix-only, there are still build portability issues to look out for. The main ones are:

* **Not all GCCs link libraries with the same flags** - for instance, linking
  shared libraries is done with "-shared" on Linux and "-bundle -undefined
  dynamic_lookup -all_load" on Mac OSX. Factoring the flags in a variable is
  a nice gesture for users of other operating systems. (LuaRocks can take
  care of the detection part and set the flag appropriately, but packages of
  other systems will benefit as well.)

* **The compiler is not always called "gcc"** - this one is for the people in
  the embedded world; in their toolchains, their cross-compilers often have
  names like "arm-nofpu-gcc". $(CC) is a standard variable in make. Just use
  that instead of "gcc" and you're good to go.

Don't:

```
bla.so:
        gcc -o bla.so -shared bla.o
```

Do:

```
LIBFLAG=-shared
# ...
bla.so:
        $(CC) -o bla.so $(LIBFLAG) bla.o
```

# Do not "overload" variables 

As mentioned in the topic about third-party libraries above, don't reuse variables just because two conceptually different locations happen to point to the same place. For example, do not assume that the directory you're using to _find_ libraries and the directory you're _installing_ libraries to is the same. That little economy will only cause confusion and trouble to your users.

Don't:

```
LIBDIR=/usr/local/lib
INCDIR=/usr/local/include
# ...
bla.so:
        $(CC) $(LIBFLAG) -o bla.so -lpng -L$(LIBDIR) -I$(INCDIR)
install:
        mkdir -p $(LIBDIR)
        cp bla.so $(LIBDIR)/lua/5.1
```

Do:

```
LIBPNG_DIR=/usr/local
LIBPNG_LIBDIR=$(LIBPNG_DIR)/lib
LIBPNG_INCDIR=$(LIBPNG_DIR)/include
LUA_DIR=/usr/local
LUA_LIBDIR=$(LUA_DIR)/lib/lua/5.1
# ...
bla.so:
        $(CC) $(LIBFLAG) -o bla.so -lpng -L$(LIBPNG_LIBDIR) -I$(LIBPNG_INCDIR)
install:
        mkdir -p $(LUA_LIBDIR)
        cp bla.so $(LUA_LIBDIR)
```
