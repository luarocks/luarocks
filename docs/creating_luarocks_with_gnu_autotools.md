# Creating LuaRocks with GNU autotools

Note that LuaRocks requires packages to be relocatable, and GNU autotools by
default builds non-relocatable packages. For many programs it's not necessary
to do anything particular to make them relocatable; applications which need to
find resources at run-time may be problematic. See GNU Smalltalk for one
approach (look at the RELOCATABILITY section in its configure.ac).
[Zee](http://github.com/rrthomas/zee) uses another approach, of patching in
paths for in-place running of the program during development, and relying on
Lua search paths at run-time, purely to find Lua modules. Search for
'in_place_lua_path'.

Use a rockspec template like the following, and call it $PACKAGE.rockspec.in:

```
package="@PACKAGE@"
 version="@VERSION@-1"
 source = {
   url = "https://github.com/downloads/<USER>/@PACKAGE@/@PACKAGE@-@VERSION@.tar.gz",
   md5 = "@MD5@",
   dir = "@PACKAGE@-@VERSION@"
 }
 description = {
   summary = "<Short summary>",
   detailed = [[
       <Detailed information.>
   ]],
   homepage = "http://github.com/<USER>/@PACKAGE@/",
   license = "<LICENSE>"
 }
 dependencies = {
   "lua >= 5.1"
 }
 build = {
   type = "command",
   build_command = "LUA=$(LUA) CPPFLAGS=-I$(LUA_INCDIR) ./configure --prefix=$(PREFIX) --libdir=$(LIBDIR) --datadir=$(LUADIR) && make clean && make",
   install_command = "make install"
 }
```

Add "$PACKAGE.rockspec.in" to AC_CONFIG_FILES in your configure.ac:

Add or amend the following rules in your Makefile.am:

```
ROCKSPEC = $(PACKAGE)-$(VERSION)-1.rockspec
```

```
$(ROCKSPEC): $(PACKAGE).rockspec dist
 	sed -e 's/@MD5@/'`$(MD5SUM) $(distdir).tar.gz | \
 	cut -d " " -f 1`'/g' < $(PACKAGE).rockspec > $@
```

```
EXTRA_DIST = $(PACKAGE).rockspec.in
```

```
DISTCLEANFILES = $(PACKAGE).rockspec
```

You can use [woger](http://github.com/rrthomas/woger/) to automate your
releases, uploading rockspecs to luarocks.org and announcements to the Lua
mailing list. The details are evolving, so see woger itself for details, and a
frequently-updated project such as
[luaposix](http://github.com/luaposix/luaposix/) for example Makefile.am code.
