# Creating a Makefile that plays nice with LuaRocks

The page about [Recommended practices for
Makefiles](recommended_practices_for_makefiles.md) mentions what you should do
in order to create a Makefile that LuaRocks can work with. What it does not do
is to explain how to interact between your rockspec and the Makefile so that
your rock will install in a way such that LuaRocks knows everything it needs
to know to handle everything after the installation (like, for example,
removal).

LuaRocks creates a few very important variables for you, that you can pass to
your Makefile. They come in 2 varieties, one set for building the module and
another set for installing it. The variables are:

For building:

* `CFLAGS` - flags for the C compiler
* `LIBFLAG` - the flags needed for the linker to create shared libraries
* `LUA_LIBDIR` - where to find the lua libraries
* `LUA_BINDIR` - where to find the lua binary
* `LUA_INCDIR` - where to find the lua headers
* `LUALIB` - the name of the lua library. This is not available nor needed on all platforms.
* `LUA` - the name of the lua interpreter

For installing:

* `PREFIX` - basic installation prefix for the module
* `BINDIR` - where to put user callable programs or scripts
* `LIBDIR` - where to put the shared libraries
* `LUADIR` - where to put the lua files
* `CONFDIR` - where to put your modules configuration

Most of these variables point immediately where you'd expect them to, but
`BINDIR`, `LIBDIR` and `LUADIR` are special. These point to a location where
you need to put the files in order for LuaRocks to move them to their final
destination. If you install your stuff here, then LuaRocks will know what
files your module installed and can later remove them.

These variables are not readily available in the Makefile, you need to tell
LuaRocks to pass them to make. A simple rockspec that will do this looks
like this:

```
package = "lrtest"
version = "1.0-1"
source = {
   url = "http://..."
}
build = {
   type = "make",
   build_variables = {
      CFLAGS="$(CFLAGS)",
      LIBFLAG="$(LIBFLAG)",
      LUA_LIBDIR="$(LUA_LIBDIR)",
      LUA_BINDIR="$(LUA_BINDIR)",
      LUA_INCDIR="$(LUA_INCDIR)",
      LUA="$(LUA)",
   },
   install_variables = {
      INST_PREFIX="$(PREFIX)",
      INST_BINDIR="$(BINDIR)",
      INST_LIBDIR="$(LIBDIR)",
      INST_LUADIR="$(LUADIR)",
      INST_CONFDIR="$(CONFDIR)",
   },
}
```

The corresponding Makefile looks like this:

```
all:
	@echo --- build
	@echo CFLAGS: $(CFLAGS)
	@echo LIBFLAG: $(LIBFLAG)
	@echo LUA_LIBDIR: $(LUA_LIBDIR)
	@echo LUA_BINDIR: $(LUA_BINDIR)
	@echo LUA_INCDIR: $(LUA_INCDIR)
	@echo LUA: $(LUA) 

install:
	@echo --- install
	@echo INST_PREFIX: $(INST_PREFIX)
	@echo INST_BINDIR: $(INST_BINDIR)
	@echo INST_LIBDIR: $(INST_LIBDIR)
	@echo INST_LUADIR: $(INST_LUADIR)
@echo INST_CONFDIR: $(INST_CONFDIR)
```

Now, if you call `luarocks make`, the output will look something
like this:

```
-- build
CFLAGS: -O2 -fPIC
LIBFLAG: -shared
LUA_LIBDIR: /usr/local/lib
LUA_BINDIR: /usr/local/bin
LUA_INCDIR: /usr/local/include

-- install
INST_PREFIX: /usr/local/lib/luarocks/rocks/lrtest/1.0-1
INST_BINDIR: /usr/local/lib/luarocks/rocks/lrtest/1.0-1/bin
INST_LIBDIR: /usr/local/lib/luarocks/rocks/lrtest/1.0-1/lib
INST_LUADIR: /usr/local/lib/luarocks/rocks/lrtest/1.0-1/lua
INST_CONFDIR: /usr/local/lib/luarocks/rocks/lrtest/1.0-1/conf
```

You will notice that the aforementioned special variables do not point to
the location you'd expect them to. LuaRocks will move files you put there
to their final destination for you, and in the process keep track of what
was installed.

The `CONFDIR` and `PREFIX` variables point to locations
where you can store configuration or other data for your module. Your code
must be made aware of these paths in order to use them. If you use the
`copy_directories` entry in the build section of your rockspec,
then what is mentioned there is copied to $(PREFIX) (i.e. a directory doc
will be available unter $(PREFIX)/doc). If you copy directories in your
`install` Makefile rule, you should do the same.

Now, if your Makefile is meant to be used standalone as well, which it
probably is, you would also want to define these variables inside of your
Makefile, but in such a way that it will not hinder LuaRocks. Luckily
variables passed on the command line to make override those defined in
the Makefile.

With this, a Makefile that is usable both from LuaRocks and standalone
might look like this:

```
CFLAGS = -fPIC -O2
LIBFLAG = -shared
LUA_LIBDIR = /usr/local/lib/lua/5.2
LUA_BINDIR = /usr/local/bin
LUA_INCDIR = /usr/local/include
LUA = lua
   
INST_PREFIX = /usr/local
INST_BINDIR = $(INST_PREFIX)/bin
INST_LIBDIR = $(INST_PREFIX)/lib/lua/5.2
INST_LUADIR = $(INST_PREFIX)/share/lua/5.2
INST_CONFDIR = $(INST_PREFIX)/etc
   
all:
	@echo --- build
	@echo CFLAGS: $(CFLAGS)
	@echo LIBFLAG: $(LIBFLAG)
	@echo LUA_LIBDIR: $(LUA_LIBDIR)
	@echo LUA_BINDIR: $(LUA_BINDIR)
	@echo LUA_INCDIR: $(LUA_INCDIR)

install:
	@echo --- install
	@echo INST_PREFIX: $(INST_PREFIX)
	@echo INST_BINDIR: $(INST_BINDIR)
	@echo INST_LIBDIR: $(INST_LIBDIR)
	@echo INST_LUADIR: $(INST_LUADIR)
	@echo INST_CONFDIR: $(INST_CONFDIR)
```

You probably don't just want to echo stuff, so here's how to use the variables
when actually building or installing something:

```
...

all: lrtest.so

lrtest.so: lrtest.o
	$(CC) $(LIBFLAG) -o $@ -L$(LUA_LIBDIR) $<

lrtest.o: lrtest.c
	$(CC) -c $(CFLAGS) -I$(LUA_INCDIR) $< -o $@

install: lrtest.so lrtest.lua
	cp lrtest.so $(INST_LIBDIR)
	cp lrtest.lua $(INST_LUADIR)
```

There is of course a lot more to a proper Makefile and rockspec, this is only
to show how to take advantage of LuaRocks' builtin helpers for this sort of
thing. Also, keep in mind that for additional external dependencies, more
variables are created by LuaRocks, which have to be passed to the Makefile in
the same way. Check the other documentation, especially [Rockspec
format](rockspec_format.md) and [Recommended practices for
Makefiles](recommended_practices_for_makefiles.md), for details.


