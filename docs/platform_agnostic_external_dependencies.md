# Platform-agnostic external dependencies

Since 0.6, LuaRocks supports specifying files for external dependency search
in a platform-agnostic way. When filenames given in the
`external_dependencies` section of a [rockspec](rockspec_format.md) don't
have any dot (".") characters, their contents are substituted according to the
patterns given in the `external_deps_patterns` table of the [configuration
file](config_file_format.md).

These patterns will typically not be used in the configuration file, as
LuaRocks provides sensible defaults. The default patterns defined on Unix are:

```
bin = {"?"}
lib = {"lib?.a", "lib?.so"}
include = {"?.h"}
```

On Windows the defaults are:

```
bin = {"?.exe", "?.bat"}
lib = {"?.lib", "?.dll"}
include = {"?.h"}
```

For example, a [rockspec](rockspec_format.md) can define an external
dependency like this:

```
external_dependencies = {
    FOO = {
       library = "foo"
    }
 }
```

and this will result in searches for libfoo.a or libfoo.so on Unix systems,
and foo.lib or foo.dll on Windows. For entries that have more than one
pattern, such as lib, only one entry needs to be satisfied.

In other words, the value "foo" you see in the
external_dependencies.FOO.library entry is the same value you would use when
linking the library, for example -lfoo. In addition, once you added FOO in the
external_dependencies, this means you can pass entries such as FOO_DIR and
FOO_LIBDIR to the `luarocks` command-line tool, in case you have these
libraries in non-standard locations. For example, if the user installed the
library in a custom location in their own home directory, it would still be
usable, like this:

```
luarocks install my_rockspec_using_foo-1.0-1.rockspec FOO_LIBDIR=/home/joeuser/foo/lib
```

When performing external dependency checks during installation (as opposed to
build) of rocks, static libraries and headers are not searched. The
`runtime_external_deps_patterns` table is used instead.

Since 3.4.0, the variable DEPS_DIR which doesn't depend on the name FOO, could
also used, like this:

```
luarocks install my_rockspec_using_foo-1.0-1.rockspec DEPS_DIR=/home/joeuser/foo/lib
```

# When filenames don't match 

If the pattern system is not enough to hide platform differences, you can
always resort to [per-platform overrides](platform_overrides.md). For example:

```
external_dependencies = {
   FOO = {
      library = "foo"
   }
   platforms = {
      win32 = {
         FOO = {
            library = "winfoo32.dll"
         }
      }
   }
}
```

# Statically linked libraries and dependencies 

If your rock links a library statically, avoid adding a library search in its
[rockspec](rockspec_format.md)'s `external_dependencies` table. Search for a
header instead, so that the external dependency search does not fail when
users install a binary rock and they don't have the library installed
separately.

