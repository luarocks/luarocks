# Rockspec format

For number fields, strings are accepted and converted using tonumber().

## Package metadata

* **rockspec_format** (string) - the file format version. Example: "1.0"
* **package** (string, mandatory field) - the name of the package. Example: "LuaSocket"
* **version** (string, mandatory field) - the version of the package, plus a suffix indicating the revision of the rockspec. Example: "2.0.1-1"
* **description** (table)
   * **description.summary** (string) - A one-line description of the package. Example: "Network support for the Lua language"
   * **description.detailed** (string) - A longer description of the package. Example: "LuaSocket is a Lua extension library that is composed by two parts: a C core that provides support for the TCP and UDP transport layers, and a set of Lua modules that add support for functionality commonly needed by applications that deal with the Internet."
   * **description.license** (string) - The license used by the package. A short name, such as "MIT" and "GPL-2" is preferred. Software using the same license as Lua 5.x should use "MIT".
   * **description.homepage** (string) - An URL for the project. This is not the URL for the tarball, but the address of a website. Example: "http://github.com/keplerproject/rings"
   * **description.issues_url** (string) (since 3.0) - An URL for the project's issue tracker. Example: "http://github.com/keplerproject/rings/issues"
   * **description.maintainer** (string) - Contact information for the _rockspec_ maintainer (which may or may not be the package maintainer -- contact for the package maintainer can usually be obtained through the address in the homepage field). Example: "John Doe &lt;john@doe.gov&gt;"
   * **description.labels** (array of strings) (since 3.0) - A list of short strings that specify labels for categorization of this rock. See the list of labels at [http://luarocks.org] for inspiration. Example: { "crypto", "network", "tls", "https" }

## Dependency information

Dependencies are represented in LuaRocks through strings with a package name followed by a comma-separated list of constraints. Each constraint consists of an operator and a version number. In this string format, version numbers are represented as naturally as possible, like they are used by upstream projects (e.g. "2.0beta3"). Internally, LuaRocks converts them to a purely numeric representation, allowing comparison following some common sense heuristics. The precise specification of the comparison criteria is the source code of the luarocks.deps module, but the test/test_deps.lua file included with LuaRocks provides some insights on what these criteria are.

* **supported_platforms** (array of strings) - If this array is not present, the rock is assumed to be portable to any platform. If present, this should contain strings containing LuaRocks platform identifiers, optionally preceded by a "!" to indicate a negative match. If only negative entries are listed, the rock is assumed to be portable to any platform except those listed. If any positive entry exists, then at least one entry must match positively to the currently running platform. Currently supported LuaRocks platform identifiers are: "unix", "windows", "win32", "cygwin", "macosx", "linux", "freebsd". Platforms may have more than one valid identifier; e.g. Linux defines both "unix" and "linux". Note that, as of 0.6, Cygwin under Windows defines {"unix", "cygwin"} but *not* "windows".
* **dependencies** (array of strings) - Each string represents a package this rock depends on, containing a package name followed by a comma-separated list of constraints. Example: `{"lfs >= 1.0, &lt; 2.0"}`. Accepted operators are the relational operators of Lua: `==` `~=` `<` `>` `<=` `>=` , as well as a special operator, `~>`, inspired by the "pessimistic operator" of RubyGems (`"~> 2"` means `">= 2, < 3"`; `"~> 2.4"` means `">= 2.4, < 2.5"`). The absence of an operator means an implicit `==` (i.e., `"lfs 1.0"` is the same as `"lfs == 1.0"`). "lua" is an special dependency name; it matches not a rock, but the version of Lua in use. Supports [per-platform overrides](platform-overrides).
* **build_dependencies** (array of strings) (since 3.0) - Dependencies that apply at build-time only, but not when installing binary (`.<platform>.rock`) or pure-Lua (`.all.rock`) rocks. Each string represents a package this rock depends on at build time, containing a package name followed by a comma-separated list of constraints. The syntax in the same as the `dependencies` field. Supports [per-platform overrides](platform-overrides).
* **external_dependencies** (table) - For each key in the external_dependencies table in the rockspec file, four variables available to the build rules are created: <i>key</i>_DIR, <i>key</i>_BINDIR, <i>key</i>_INCDIR and <i>key</i>_LIBDIR. These are not overwritten if already set (e.g. by the LuaRocks config file or through the command-line). The base prefix for these can be given explicitly setting <i>key</i>_DIR in the config file or through the command-line, or implicitly, defaulting to the value of default_external_deps_dir, set in the config file. Values in the external_dependencies table are tables that may contain a "header" or a "library" field, with filenames to be tested for existence. Example: `{ EXPAT = { header = "expat.h" } }` -- on Unix, this will check that EXPAT_DIR/include/expat.h exists and will create variables accordingly. You can also use platform overrides or specify files of external dependencies in a [platform-agnostic manner](platform-agnostic-external-dependencies). Supports [per-platform overrides](platform-overrides).
* **test_dependencies** (array of strings) (since 3.0) - Dependencies that apply at test-time only, that is, only needed when running `luarocks test`. Each string represents a package this rock depends on at test time, containing a package name followed by a comma-separated list of constraints. The syntax in the same as the `dependencies` field. Supports [per-platform overrides](platform-overrides).

## Build rules

* **source** (table, mandatory field) - Contains information on how to fetch sources to build this rock. Supports [per-platform overrides](platform-overrides).
   * **source.url** (string, mandatory field) - the URL of the package source archive. Examples: "http://github.com/downloads/keplerproject/wsapi/wsapi-1.3.4.tar.gz", "git://github.com/keplerproject/wsapi.git". Note that this field is ignored when running [luarocks make](luarocks_make.md), which uses the sources from your current directory instead. Different protocols are supported:
      * `cvs://` - for the CVS source control manager
      * `file://` - for URLs in the local filesystem (note that for Unix paths, the root slash is the third slash, resulting in paths like `"file:///full/path/filename"`
      * `ftp://` - for FTP URLs
      * `git://` - for the Git source control manager
      * `git+file://` - for the Git source control manager when using repositories that need file:// URLs
      * `git+http://` - for the Git source control manager when using repositories that need http:// URLs
      * `git+https://` - for the Git source control manager when using repositories that need https:// URLs
      * `git+ssh://` - for the Git source control manager when using repositories that need SSH login, such as `git@example.com/myrepo`
      * `hg://` - for the Mercurial source control manager
      * `hg+http://` - for the Mercurial source control manager using repositories that need http:// URLs
      * `hg+https://` - for the Mercurial source control manager using repositories that need https:// URLs
      * `hg+ssh://` - for the Mercurial source control manager using repositories that need SSH login
      * `http://` - for HTTP URLs
      * `https://` - for HTTPS URLs
      * `hg://` - for the Mercurial source control manager
      * `sscm://` - for the SurroundSCM source control manager
      * `svn://` - for the Subversion source control manager
   * **source.md5** (string) - the MD5 sum for the source archive. Example: "9ca22fd9f9413b54802d3d40b38c4e5c"
   * **source.file** (string) - the filename of the source archive. Can be omitted if it can be inferred from the `source.url` field. Example: "luasocket-2.0.1.tar.gz"
   * **source.dir** (string) - the name of the directory created when the source archive is unpacked. Can be omitted if it can be inferred from the `source.file` field. Example: "luasocket-2.0.1"
   * **source.tag** (string) - for SCM-based URL protocols such as "cvs://" and "git://", this field can be used to specify a tag for checking out sources. Example: "HEAD" (For compatibility reasons, `source.cvs_tag` is also accepted.)
   * **source.branch** (string) - for SCM-based URL protocols such as "git://", this field can be used to specify a branch for checking out sources. Example: "v1.0"
   * **source.module** (string) - for SCM-based URL protocols such as "cvs://" and "git://", this field can be used to specify the module to be checked out. Can be omitted if it is the same as the basename of the `source.url` field. Example: "cgilua"  (For compatibility reasons, `source.cvs_module` is also accepted.)
* **build** (table) - Contains all information pertaining _how_ to build a rock. Supports [per-platform overrides](platform-overrides).
   * **build.type** (string) - The LuaRocks build back-end to use. Example: "make"
   * **build.install** (table) - For packages which don't provide means to install modules and expect the user to copy the .lua or library files by hand to the proper locations. This table contains categories of files. Each category is itself a table, where the array part is a list of filenames to be copied. For module directories only, in the hash part, other keys are identifiers in Lua module format, to indicate which subdirectory the file should be copied to. For example, `build.install.lua = {["foo.bar"] = "src/bar.lua"}` will copy src/bar.lua to the foo directory under the rock's Lua files directory. The available categories are:
      * **build.install.lua** (table) - Lua modules written in Lua. 
      * **build.install.lib** (table) - Dynamic libraries implemented compiled Lua modules. 
      * **build.install.conf** (table) - Configuration files.
      * **build.install.bin** (table) - Lua command-line scripts.
   * **build.copy_directories** (array of strings) (since 1.0) - A list of directories in the source directory to be copied to the rock installation prefix as-is. Useful for installing documentation and other files such as samples and tests. Default is {"doc"} for documentation to be locally installed in the rocktree.
      * :warning: **Warning:** - do not use the following directory names: "lua", "lib", "rock_manifest" or the name of your rockspec; those names are used by the .rock format internally, and attempting to copy directories with those names using the build.copy_directories directive will cause a clash.
   * **build.patches** (table) - A rockspec can embed patches in unified diff ("diff -u") format, which are applied prior to building the modules. Each entry in this table should contain a descriptive file name for the patch a the key, and the text of the patch as the value (typically, as a long string). The patch is applied from within the source.dir directory, and file names ignore the first directory level (in other word, patches are applied with the equivalent of "patch -p 1"). Keep in mind that the actual text of the patch cannot be indented. Example: 
```
patches = {
   ["lua51-support.diff"] = [[
--- old/mymodule.c....
]]
}
```

### Build back-ends

Build back-ends indicate how to build a package. 
Fields of the `build` table other than `build.type`, `build.platforms` and `build.install` are specific to the given type. 

#### builtin

This is a mode for packages distributing pure Lua or simple C modules. All pathnames used are relative to `source.dir`. The goal is to allow module authors to specify compilation of their C code in a clean, simple and portable way.

* **build.modules** (array) - An array in which keys are module names in the format normally used by the require() function, and values may be:
   * strings - pathnames of Lua files or C sources, for modules based on a single source file.
   * array of strings - pathnames of C sources of a simple module written in C composed of multiple files.
   * table - a table containing one or more fields:
      * **build.sources** (array of strings) - the only mandatory field, pathnames of C sources.
      * **build.libraries** (array of strings) - external libraries to be linked.
      * **build.defines** (array of strings) - a list of C defines. eg. { "FOO=bar", "USE_BLA" }
      * **build.incdirs** (array of strings) - directories to be added to the compiler's headers lookup directory list.
      * **build.libdirs** (array of strings) - directories to be added to the linker's library lookup directory list.

#### make

Indicates the package uses a Makefile.

   * **build.makefile** (string) - Makefile to be used. Default is "Makefile" on Unix variants and "Makefile.win" under Win32.
   * **build.build_target** (string) - Default is "".
   * **build.build_pass** (boolean) - Whether to perform a make pass on the target indicated by `build.build_target`. Default is true (i.e., to run make).
   * **build.install_target** (string) - Default is "install".
   * **build.install_pass** (boolean) - Whether to perform a make pass on the target indicated by `build.build_target`. Default is true (i.e., to run make).
   * **build.build_variables** (table) - Assignments to be passed to make during the build pass. Default is {}.
   * **build.install_variables** (table) - Assignments to be passed to make during the install pass. Default is {}.
   * **build.variables** (table) - Assignments to be passed to make on both passes. Default is {}.

Variables expected by this back-end to be provided by the configuration file are:

   * **CC** - Command to call the C compiler.
   * **CFLAGS** - Flags to be passed to the C compiler. May be empty.
   * **LIBFLAG** - Flag to be passed to the C compiler to instruct it to build a shared library.

These are usually detected by the default configuration, but can be overridden
by the [configuration file](config-file-format). See also the "Variables"
section of the [Config file format](config_file_format.md) specification for
other path variables that are defined automatically, and the documentation on
the `external_dependencies` entry above for variables that are automatically
generated based on paths of external dependencies.

#### cmake

Indicates the package uses CMake for building.

* **build.cmake** (string) - If given, its contents are used as the CMakeLists.txt file. If not given, it is assumed that the package provides a CMakeLists.txt file.
* **build.variables** (table) - Additional variables to be passed to CMake. Equals to calling CMake with attributes: `cmake -Dkey1=value1 -Dkey2=value2 ...`

Additionally you can specify these environment variables when calling LuaRocks:

   * **CMAKE_MODULE_PATH** - Tells CMake where to search for additional modules.
   * **CMAKE_INCLUDE_PATH** - Path to desired include directory.
   * **CMAKE_LIBRARY_PATH** - Path to libraries.

#### command

A simple backend called "command" is also provided, in which build commands are typed in directly in the rockspec file.

* **build.build_command** (string) - Command to run to build the package.
* **build.install_command** (string) - Command to run to install the package.

#### none

A null build back-end. Indicates that there is no build to perform.

## Test rules

* **test** (table) - Contains all information pertaining how to test a rock. Supports [per-platform overrides](platform-overrides).

### Test back-ends

Test back-ends indicate how to test a package. 
Fields of the `test` table other than `test.type` and `test.platforms` are specific to the given type. 

#### busted

If `test.type` is not specified, this type is auto-detected if `.busted` is present in the root of the source tree.

* **test.flags** (array of string) - Additional CLI flags to pass to Busted when running.

#### command

If `test.type` is not specified, this type is auto-detected if a file called `test.lua` is present in the root of the source tree.

* **test.script** (string) - Filename of a Lua script to run as a test. Only one of `script` or `command` should be passed.
* **test.command** (string) - Filename of a shell command to run as a test. Only one of `script` or `command` should be passed.
* **test.flags** (array of string) - Additional CLI flags to pass to either the script or command when running.
