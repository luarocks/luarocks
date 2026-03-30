## LuaRocks 3.12.1

> Released 17/Jun/2025

* rockspec: re-add deprecated function type().
  Removing this broke the behavior of some luarocks.build
  plugins. LuaRocks does not have a stable public API,
  but since this function was returned as part of the
  function signature, we'll revert this as a deprecated
  function, to be removed in LuaRocks 4.0. No other
  reverts are planned for the sake of restoring private APIs.

## LuaRocks 0.3.1

> Released 18/Dec/2007

* Improved search: results now feature separate lists for source and binary rocks.
* Windows support for the "module" build type (using Visual Studio).
* Many assorted bugfixes.


## LuaRocks 0.3

> ReleA

## LuaRocks 3.12.0

> Released 05/Jun/2025

LuaRocks 3.12.0 marks the transition of the implementation of the tool from
Lua to Teal! This was implemented by Victor Ilchev as his Google Summer of
Code project.

### What's new

* Transition entire implementation from Lua to Teal!
* `luarocks upload`: include .src.rock file when given.
* Various Windows fixes:
  * Prioritize `bin` over `lib` for `LUA_LIBDIR` on Windows.
  * `luarocks upload`: Accept Windows-style paths when sending
    multipart data. (#1687)
  * Update pe-parser to 0.6.
  * Fix `LUA_LIBDIR` for MSVC installations. (#1744)
  * Fixed make check for msys2 mingw system. (#1745)
  * Override default C compiler to `cc.exe` on MSYS2 (#1754)
  * Allow Lua C modules to be uninstalled on MSYS2. (#1756)
  * Cygwin fixes for `external_deps_patterns` and
    `runtime_external_deps_patterns`. (#1782)
* Only create binary wrapper for Lua scripts. (#1738)
* Project dir initialized via `luarocks init` has higher
  precedence than `local_by_default` configuration. (#1682)
* add `LUA_VERSION` build variable for rockspecs.
* Rockspec format addition, feature-gated with
  `rockspec_format = "3.1`:
  * add build variables for rockspecs with the directories
    of its dependencies: `<DEPENDENCY_NAME>_ROCKDIR`.
* Avoid overwriting CMake variables from rockspec.
* Allow loading JSON-formatted manifest, to circumvent
  a LuaJIT bug when loading Lua files.
* Various other minor fixes.

## What's new in LuaRocks 3.11.1

> Released 31/May/2024

* Fixes:
  * normalize namespace names to lowercase when performing
    dependency resolution, to match CLI behavior
  * `luarocks build`: ensure `--force` works
  * `luarocks init`: check if we can create .gitignore
  * Unix: honor umask correctly
  * Fix error when failing to open cached files
  * Fix behavior of luarocks.lock file when dealing
    with dependencies


## What's new in LuaRocks 3.11.0

> Released 13/Mar/2024

* Features:
  * `luarocks build` and `luarocks install` no longer rebuild
    or reinstall if the version is already installed
    (`--force` overrides).
  * More aggressive caching of the manifest file (does not
    hit `luarocks.org` again if the cached manifest is younger
    than 10 seconds).
  * Drops stale lock files (older than 1 hour).
  * More informative error reports on bad configurations of
    Lua paths (`LUA_INCDIR`, `LUA_LIBDIR`).
  * Better error messages when lacking permissions.
  * Bumps vendored dkjson dependency to 2.7.
  * `--verbose` output now prints the LuaRocks configuration,
    for more informative bug reports.
* Fixes:
  * Passing `--global` always LuaRocks target the system tree.
  * Does not crash if `root_dir` is a table.
  * Does not try to lock rocks trees when using `--pack-binary-rock`
    or `--no-install`.
  * Checks permissions ahead of trying to lock trees,
    to provide better error messages.
  * Avoids LuaSec version mismatch by refusing to use LuaSec
    versions below 1.1.
  * Does not set up a "project environment" when running
    `make` on the LuaRocks sources.
  * Windows:
    * Avoid excessive calls to `icacls`, resulting in
      performance improvements.
    * Parses slashes correctly when reading a rock's `rock_manifest`.
    * Fix setting of environment variables.
    * install.bat sets LUALIB.
    * Improved help for `luarocks path`.


## What's new in LuaRocks 3.10.0

> Released 27/Feb/2024

* Features:
  * Introduce file-based locking for concurrent access
    control. Previously, LuaRocks would produce undefined behavior
    when running two instances at the same time.
  * Rockspec quality-of-life improvements:
    * Using an unknown `build.type` now automatically
      implies a build dependency for `luarocks-build-<build.type>`.
    * Improve `rockspec.source.dir` autodetection.
    * `builtin` build mode now automatically inherits include
      and libdirs from `external_dependencies` if not set
      explicitly.
  * improved and simplified Lua interpreter search.
    * `lua_interpreter` config value is deprecated in favor
      of `variables.LUA` which contains the full interpreter path.
  * `luarocks-admin remove` now supports the `file://`
    protocol for managing local rocks servers.
  * Bundled dkjson library, so that `luarocks upload` does not
    require an external JSON library.
  * New flags for `luarocks init`: `--no-gitignore`,
    `--no-wrapper-scripts`, `--wrapper-dir`.
  * `luarocks config` now attempts updating the system config
    by default when `local_by_default` is `false`.
  * New flag for `luarocks path`: `--full`, for use with
    `--lr-path` and `--lr-cpath`.
* Fixes:
  * various Windows-specific fixes:
    * `build.install_command` now works correctly on Windows.
    * do not attempt to set "executable" permissions for folders
      on Windows.
    * better handling of Windows backslash paths.
    * fix program search when using absolute paths and `.exe` files.
    * improved lookup order for library dependencies.
    * `LUALIB` filename detection is now done dynamically at
      runtime and not hardcoded by the Windows installer.
    * prevent LuaRocks from blocking `luafilesystem` from being
      removed on Windows.
  * `luarocks build` no longer looks for Lua headers when installing
    pure-Lua rocks.
  * `luarocks build` table in rockspecs now gets some additional validation
    to prevent crashes on malformed rockspecs.
  * `build.builtin` now compiles C modules in a temporary directory,
    avoiding name clashes
  * `build_dependencies` now correctly installs dependencies
    for the Lua version that LuaRocks is running on, and not
    the one it is building for with `--lua-version`.
  * `build_dependencies` can now use a dependency available
    in any rocks tree (system, user, project).
  * `luarocks config` now prints boolean values correctly on Lua 5.1.
  * `luarocks config` now ensures the target directory exists when saving
    a configuration.
  * `luarocks init` now injects the project's `package.(c)path` in the
    Lua wrapper.
  * `luarocks lint` no longer crashes if a rockspec misses a `description` field.
  * `luarocks test` now handles malformed `command` entries gracefully.
  * if `--lua-*` flags are given in the CLI, the hardcoded values
    are never used.
  * the "no downloader" error is now shown only once, and not
    once per failed mirror.
  * project dir is always presented normalized
  * catch the failure to setup `LUA_BINDIR` early.
  * when using `--pack-binary-rock` and a `zip` program is
    unavailable, report that instead of failing cryptically.
  * More graceful handling when failing to create a local cache.
  * Avoid confusion with macOS multiarch binaries on system detection.
  * Add `--tree` to the rocks trees list.
  * Better support for LuaJIT versions with extra
    suffixes in their version numbers.
  * Don't use floats to parse Lua version number.
  * Various fixes related to path normalization.


## What's new in LuaRocks 3.9.2

> Released 08/Dec/2022

* Configuration now honors typical compiler environment variables
  for all build backends:
  * `MAKE`, `CC`, `AR`, `RANLIB` on Unix
  * `MAKE`, `CC`, `AR`, `WINDRES`, `LINK`, `MT` on Windows
* `builtin` build mode now supports Clang on Windows
* `luarocks test` now checks/installs all dependency kinds
  (build, runtime, test), so you don't need to run
  `luarocks make --only-deps` in CI environments to get all
  dependencies needed to run a test
* MinGW: default to x86_64 compiler on 64-bit platforms
* Fixed crash if `variables.LUA*` are unset in configuration
* Fix `luarocks test --prepare` behavior for non-Busted tests
* Internal API fixes
  * `path.path_to_module`: accept custom file extensions in
    package path variables
  * `persist.save_from_table`: ensure directory exists when
    saving a file


## What's new in LuaRocks 3.9.1

> Released 01/Jul/2022

* Fixed error message when Lua library is not found
* Fixed build of Windows binary
* A couple of minor feature additions:
  * API: `loader.which` has a new mode for searching `package.path/cpath`
    * Adds a new second argument, `where`, a string which indicates places
      to search for the module. If `where` contains `"l"`, it will search
      using the LuaRocks loader; if it contains `"p"`, it will look in the
      filesystem using `package.path` and `package.cpath`. You can use both
      at the same time.
  * `--no-project` flag can be used to override `.luarocks` project directory
    detection

## What's new in LuaRocks 3.9.0

> Released 17/Apr/2022

* `builtin` build mode now always respects CC, CFLAGS and LDFLAGS
* Check that lua.h version matches the desired Lua version
* Check that the version of the Lua C library matches the desired Lua version
* Fixed deployment of non-wrapped binaries
* Fixed crash when `--lua-version` option is malformed
* Fixed help message for `--pin` option
* Unix: use native methods and don't always rely on $USER to determine user
* Windows: use native CLI tooling more
* macOS: support .tbd extension when checking for libraries
* macOS: add XCode SDK path to search paths
* macOS: add best-effort heuristic for library search using Homebrew paths
* macOS: avoid quoting issues with LIBFLAG
* macOS: deployment target is now 11.0 on macOS 11+
* added DragonFly BSD support
* LuaRocks test suite now runs on Lua 5.4 and LuaJIT
* Internal dependencies of standalone LuaRocks executable were bumped


## What's new in LuaRocks 3.8.0

> Released 08/Nov/2021

* Support GitHub's protocol security changes transparently.
  * The raw git:// protocol will stop working on GitHub. LuaRocks already
    supports git+https:// as an alternative, but to avoid having to update
    every rockspec in the repository that uses git://github.com, which would
    require a large coordinated effort, LuaRocks now auto-converts github.com
    and www.github.com URLs that use git:// to git+https://
* `luarocks test` has a new flag `--prepare` that checks, downloads and
  installs the tool requirements and rockspec dependencies but does not
  run the test suite for the rockspec being tested.
* Code tweaks so that LuaRocks can run on a Lua interpreter built without
  the `debug` library.
* `luarocks upload` supports uploading pre-packaged `.src.rock` files.
* Configuration fixes for OpenBSD.
* Respect the existing value for the `variables.LUALIB` configuration
  variable if given explicitly by the user in the config file, rather
  than trying to override it with auto-detection.
* Windows fixes for setting file permissions:
  * Revert the use of `Everyone` back to `*S-1-1-0`
  * Quote the use of the `%USERNAME%` variable to support names with spaces


## What's new in LuaRocks 3.7.0

> Released 13/Apr/2021

* Improved connectivity resiliency
  * LuaRocks can now use mirrors for downloading rocks even if downloading
    the manifest from the main server succeeds.
    In previous versions, LuaRocks would check whether to use a mirror in the first
    download operation, when it fetches the manifest. Once the server
    (luarocks.org or one of its default mirrors) was chosen, it would stick with
    it for the rest of the command.
    The resulting behavior was that if the manifest fails to load, it switches to
    a mirror and continues from there. But if the manifest fetches ok and the then
    actual rock download fails, it would give up, instead of trying that in a
    mirror as well.
    Now, it retries every download on a mirror whenever the base URL matches one
    configured in cfg.rocks_servers. The original behavior was satisfactory if
    there was complete downtime in the main server, but this new behavior should
    make the CLI much more resilient with regard to any intermittent failures
    happening on the main server.
* On Unix, it now respects environment variables $XDG_CACHE_HOME and $XDG_CONFIG_HOME
  * This means the user's configuration typically resides in ~/.config/luarocks/
    as per the XDG standard
  * The legacy path ~/.luarocks/ continues to be tested first, for backwards
    compatibility
* Fixes check for the default Lua version set in the user's home configuration
* Fixes an issue on Windows where it would incorrectly revoke permissions
  from the current user when installing


## What's new in LuaRocks 3.6.0

> Released 30/Mar/2021

* Adds a double-check step to verify that all files from a rock are installed
* Improve resilience of the manifest reader to deal with manifests
  written with older versions of LuaRocks lower than 3.0
* `luarocks pack` now checks that the directory inside the archive being packed
  as a `.src.rock` actually exists, refusing to pack an invalid rock from
  a badly configured rockspec.
* Fixes behavior of `luarocks pack` when the `url` entry of a rockspec
  points to a bare file.
* Remove an entry from the manifest if the rock itself is already missing
* The `configure` script now checks that the version of `lua.h`
  found matches that of the Lua interpreter detected or configured
* Fixes the renaming of scripts when multiple versions are installed
* Fixes availability check for `svn` for rockspecs using Subversion
* Fixes for running with an empty PATH environment variable
* Portability improvements:
  * Windows: vcvarsall.bat output is now properly redirected to NUL
    meaning that the output of `luarocks path` can be used in scripts
  * Fixes autodetection for Cygwin
  * Handles macOS versions greater than 10.10
  * Adds platform specific configurations for NetBSD
  * Respects CC/CFLAGS/LDFLAGS on FreeBSD
* Luacheck now runs on the LuaRocks CI
* Distributed binaries are built using Lua 5.3


## What's new in LuaRocks 3.5.0

> Released 10/Dec/2020

This is a small release:

* Added support for MSYS2 and Mingw-w64
* Reverted the change in MSVC environment variable set up script
* Fixes a bug where `--verbose` raised an exception with a nil argument
* Added proper error messages when lua.h is invalid

## What's new in LuaRocks 3.4.0

> Released 25/Sep/2020

### Features

* `luarocks make` now supports `--only-deps`
* `luarocks make` new flag: `--no-install`, which only performs
  the compilation step
* `--deps-only` is now an alias for `--only-deps` (useful in case
  you always kept getting it wrong, like me!)
* `luarocks build` and `luarocks make` now support using
  `--pin` and `--only-deps` at the same time, to produce a lock
  file of dependencies in use without installing the main package.
* `luarocks show` can now accept a substring of the rock's name,
  like `list`.
* `luarocks config`: when running without system-wide permissions,
  try storing the config locally by default.
  Also, if setting both lua_dir and --lua-version explicitly,
  auto-switch the default Lua version.
* `luarocks` with no arguments now prints more info about the
  location of the Lua interpreter which is being used
* `luarocks new_version` now keeps the old URL if the MD5 doesn't
  change.
* `DEPS_DIR` is now accepted as a generic variable for dependency
  directories (e.g. `luarocks install foo DEPS_DIR=/usr/local`)
* Handle quoting of arguments at the application level, for
  improved Windows support
* All-in-one binary bundles `dkjson`, so it runs `luarocks upload`
  without requiring any additional dependencies.
* Tweaks for Terra compatibility

### Fixes

* win32: generate proper temp filename
* No longer assume that Lua 5.3 is built with compat libraries and
  bundles `bit32`
* `luarocks show`: do not crash when rockspec description is empty
* When detecting the location of `lua.h`, check that its version
  matches the version of Lua being used
* Fail gracefully when a third-party tool (wget, etc.) is missing
* Fix logic for disabling mirrors that return network errors
* Fix detection of Lua path based on arg variable
* Fix regression on dependency matching of luarocks.loader


## What's new in LuaRocks 3.3.1

> Released 07/Feb/2020

This is a bugfix release:

* Fix downgrades of rocks containing directories: stop it
  from creating spurious 0-byte files where directories have been
* Fix error message when attempting to copy a file that is missing
* Detect OpenBSD-specific dependency paths

## What's new in LuaRocks 3.3.0

> Released 28/Jan/2020

### Features

* **Dependency pinning**
  * Adds a new flag called `--pin` which creates a `luarocks.lock`
    when building a rock with `luarocks build` or `luarocks make`.
    This lock file contains the exact version numbers of every
    direct or indirect dependency of the rock (in other words,
    it is the transitive closure of the dependencies.)
    For `make`, the `luarocks.lock` file is created in the current
    directory.
    The lock file is also installed as part of the rock in
    its metadata directory alongside its rockspec.
    When using `--pin`, if a lock file already exists, it is
    ignored and overwritten.
  * When building a rock with `luarocks make`, if there is a
    `luarocks.lock` file in the current directory, the exact
    versions specified there will be used for resolving dependencies.
  * When building a rock with `luarocks build`, if there is a
    `luarocks.lock` file in root of its sources, the exact
    versions specified there will be used for resolving dependencies.
  * When installing a `.rock` file with `luarocks install`, if the
    rock contains a `luarocks.lock` file (i.e., if its dependencies
    were pinned with `--pin` when the rock was built), the exact
    versions specified there will be used for resolving dependencies.
* Improved VM type detection to support moonjit
* git: Support for shallow recommendations
* Initial support for Windows on ARM
* Support for building 64-bit Windows all-in-one binary
* More filesystem debugging output when using `--verbose` (now it
  reports operations even when using LuaFileSystem-backed implementations)
* `--no-manifest` flag for creating a package without updating the
  manifest files
* `--no-doc` flag is now supported by `luarocks make`

### Performance improvements

* Speed up dependency checks
* Speed up installation and deletion when deploying files
* build: do not download sources when when building with `--only-deps`
* New flag `--check-lua-versions`: when a rock name is not found, only
  checks for availability in other Lua versions if this flag is given

### Fixes

* safer rollback on installation failure
* config: fix `--unset` flag
* Fix command name invocations with dashes (e.g. `luarocks-admin make-manifest`)
* Fix fallback to PATH search when Lua interpreter is not configured
* Windows: support usernames with spaces
* Windows: fix generation of temporary filenames (#1058)
* Windows: force `.lib` over `.dll` extension when resolving `LUALIB`


## What's new in LuaRocks 3.2.1

> Released 05/Sep/2019

* fix installation of LuaRocks via rockspec (`make bootstrap` and
`luarocks install`): correct a problem in the initialization of the
luarocks.fs module and its interaction with the cfg module.
* fix luarocks build --pack-binary-rock --no-doc
* fix luarocks build --branch
* luarocks init: fix Lua wrapper for interactive mode
* fix compatibility issues with command add-ons loaded via
luarocks.cmd.external modules
* correct override of config values via CLI flags


## What's new in LuaRocks 3.2.0

> Released 28/Aug/2019

LuaRocks 3.2.0 now uses argument parsing based on argparse
instead of a homegrown parser. This was implemented by Paul
Ouellette as his Google Summer of Code project, mentored by
Daurnimator.

Release highlights:

* Bugfix: luarocks path does not change the order of pre-existing path
items when prepending or appending to path variables
* Bugfix: fix directory detection on the Mac
* When building with --force-config, LuaRocks now never uses the
"project" directory, but only the forced configuration
* Lua libdir is now only checked for commands/platforms that really
need to link Lua explicitly
* LuaJIT is now detected dynamically
* RaptorJIT is now detected as a LuaJIT variant
* Improvements in Lua autodetection at runtime
* luarocks new_version: new option --dir
* luarocks which: report modules found via package.path and
package.cpath as well
* install.bat: Improved detection for Visual Studio 2017 and higher
* Bundled LuaSec in all-in-one binary bumped to version 0.8.1


## What's new in LuaRocks 3.1.3

> Released 06/Jun/2019

This is another bugfix release, that incldes a couple of fixes,
including better Lua detection, and fixes specific to MacOS and
FreeBSD.


## What's new in LuaRocks 3.1.2

> Released 07/May/2019

This is again a small fix release.


## What's new in LuaRocks 3.1.1

> Released 06/May/2019

This is a hotfix release fixing an issue that affected initialization
in some scenarios.


## What's new in LuaRocks 3.1.0

> Released 30/Apr/2019

### More powerful `luarocks config`

The `luarocks config` command used to only list the current
configuration. It is now able to query and also _set_ individual
values, like `git config`. You can now do things such as:

   luarocks config variables.OPENSSL_DIR /usr/local/openssl
   luarocks config lua_dir /usr/local
   luarocks config lua_version 5.3

and it will rewrite your luarocks configuration to store that value
for later reuse. Note that setting `lua_version` will make that Lua
version the default for `luarocks` invocations (you can always
override on a per-call basis with `--lua-version`.

You can specify the scope where you will apply the configuration
change: system-wide, to the user's home config (with --local), or
specifically to a project, if you run the command from within a
project directory initialized with `luarocks init`.

### New `--global` flag

Some users prefer that LuaRocks default to system-wide installations,
some users prefer to install everything to their home directory. The
`local_by_default` configuration file controls this preference: when
it is off, the `--local` file triggers user-specific. Before 3.1.0
there was no convenient way to trigger system-wide installations when
`local_by_default` was set to true. LuaRocks 3.1.0 adds a `--global`
flag to this purpose. To enable local-by-default, you can now do:

   luarocks config local_by_default true

### `luarocks make` can deal with patches

A rockspec can include embedded patch files, which are applied when a
source rock is built. Now, when you run `luarocks make` on a source
tree unpacked with `luarocks unpack`, the patches will be applied as
well (and a hidden lockfile is created to avoid the patches to be
re-applied incorrectly).

### Smarter defaults when working with projects

When working on a project initialized with `luarocks init`, the
presence of a ./.luarocks/config-5.x.lua file will be enough to detect
the project-based workflow and have `luarocks` default to that 5.x
version. That means the `./luarocks` wrapper becomes less necessary;
the `luarocks` from your $PATH will deal with the project just fine,
git-style.

### And more!

There are also other improvements. LuaRocks uses the manifest cache a
bit more aggressively, resulting in increased performance. Also, it no
longer complains with a warning message if the home cache cannot be
created (it just uses a temporary dir instead). And of course, the
release includes multiple bugfixes.


## What's new in LuaRocks 3.0.4

> Released 30/Oct/2018

* Fork-free platform detection at startup
* Improved detection of the default rockspec in commands such as `luarocks test`
* Various minor bugfixes


## What's new in LuaRocks 3.0.3

> Released 15/Sep/2018

LuaRocks 3.0.3 is a minor bugfix release, fixing a regression in
luarocks.loader introduced in 3.0.2.


## What's new in LuaRocks 3.0.2

> Released 07/Sep/2018

* Improvements in luarocks init, new --reset flag
* write_rockspec: --lua-version renamed to --lua-versions
* Improved behavior in module autodetection
* Bugfixes in luarocks show
* Fix upgrade/downgrade when a single rock has clashing module
filenames (should fix the issue when downgrading luasec)
* Fix for autodetected external dependencies with non-alphabetic
characters (should fix the libstdc++ issue when installing xml)


## What's new in LuaRocks 3.0.1

> Released 14/Aug/2018

* Numerous bugfixes including:
   * Handle missing global `arg`
   * Fix umask behavior
   * Do not overwrite paths in format 5.x.y when cleaning up path
variables (#868)
   * Do not detect files under lua_modules as part of your sources
when running `luarocks write_rockspec`
   * Windows: do not hardcode MINGW in the all-in-one binary: instead
it properly detects when running from a Visual Studio Developer
Console and uses that compiler instead
   * configure: --sysconfdir was fixed to its correct meaning: it now
defaults to /etc and not /etc/luarocks (`/luarocks` is appended to the
value of sysconfdir)
   * configure: fixed --force-config
* Store Lua location in config file, so that a user can run `luarocks
init --lua-dir=/my/lua/location` and have that location remain active
for that project
* Various improvements to the Unix makefile, including $(DESTDIR)
support and an uninstall rule
* Autodetect FreeBSD-style include paths (/usr/include/lua5x/)


## What's new in LuaRocks 3.0.0

> Released 25/Jul/2018

- [New rockspec format](#new-rockspec-format)
- [New commands](#new-commands), including [luarocks init](https://github.com/luarocks/luarocks/wiki/Project:-LuaRocks-per-project-workflow) for per-project workflows
- [New flags](#new-flags), including `--lua-dir` and `--lua-version` for using multiple Lua installs with a single LuaRocks
- [New build system](#new-build-system)
- [General improvements](#general-improvements), including [namespaces](https://github.com/luarocks/luarocks/wiki/Namespaces)
- [User-visible changes](#user-visible-changes), including some **breaking changes**
- [Internal changes](#internal-changes)

### New rockspec format

**New rockspec format:** if you add `rockspec_format = "3.0"` to your rockspec,
you can use a number of new features. Note that these rockspecs will only work
with LuaRocks 3.0 and above, but older versions will detect that directive and
fail gracefully, giving the user a message telling them to upgrade. Rockspecs
without the `rockspec_format` directive are interpreted as having format 1.0
(the same format from LuaRocks series 1.x and 2.x) and are still supported.

The following features are only enabled if `rockspec_format = "3.0"` is set in
the rockspec:

* Build type `builtin` is the default if `build.type` is not specified.
* The `builtin` type auto-detects modules using the same heuristics as
  `write_rockspec` (for example, if you have a `src` directory). With
  auto-detection of the build type and modules, many rockspecs don't
  even need an explicit `build` table anymore.
* New table `build_dependencies`: dependencies used only for running
  `luarocks build` but not when installing binary rocks.
* New table `test_dependencies`: dependencies used only for running `luarocks test`
* New table `test`: settings for configuring the behavior of `luarocks test`.
  Supports a `test.type` field so that the test backend can be specified.
  Currently supported test backends are:
  * `"busted"`, for running [Busted](https://olivinelabs.com/busted)
  * `"command"`, for running a plain command.
  * Custom backends can be loaded via `test_dependencies`
* New field `build.macosx_deployment_target = "10.9"` is supported in Mac platforms,
  and adjusts `$(CC)` and `$(LD)` variables to export the corresponding
  environment variable.
* LuaJIT can be detected in dependencies and uses version reported by the
  running interpreter: e.g. `"luajit >= 2.1"`.
* Auto-detection of `source.dir` is improved: when the tarball contains
  only one directory at the root, assume that is where the sources are.
* New `description` fields:
  * `labels`, an array of strings;
  * `issues_url`, URL to the project's bug tracker.
* `cmake` build type now supports `build.build_pass` and `build_install_pass`
  to disable `make` passes.
* `git` fetch type fetches submodules by default.
* Patches added in `patches` can create and delete files, following standard
  patch rules.

### New commands

* **New command:** `luarocks init`. This command performs the setup for using
  LuaRocks in a "project directory":
  * it creates a `lua_modules` directory in the current directory for
    storing rocks
  * it creates a `.luarocks/config-5.x.lua` local configuration file
  * it creates `lua` and `luarocks` wrapper scripts in the current
    directory that are configured to use `lua_modules` and
    `.luarocks/config-5.x.lua`
  * if there are no rockspecs in the current directory, it creates one
    based on the directory name and contents.
* **New command:** `luarocks test`. It runs a rock's test suite, as specified
  in the new `test` section of the rockspec file. It also does some
  autodetection, so it already works with many existing rocks as well.
* **New command:** `luarocks which`. Given the name of an installed, it tells
  you which rock it is a part of. For example, `luarocks which lfs`
  will tell you it is a part of `luafilesystem` (and give the full
  path name to the module). In this sense, `luarocks which` is the
  dual command to `luarocks show`.

### New flags

* **New flags** `--lua-dir` and `--lua-version` which can be used with
  all commands. This allows you to specify a Lua version and installation
  prefix at runtime, so a single LuaRocks installation can be used
  to manage packages for any Lua version. It is no longer necessary to
  install separate copies of LuaRocks to manage packages for Lua 5.x
  and 5.y.
* **New flags** added to `luarocks show`: `--porcelain`, giving a stable
  script-friendly output (named after the Git `--porcelain` flag that
  serves the same purpose) and `--rock-license`.
* **New flag** `--temp-key` for `luarocks upload`, allowing you to easily
  upload rocks into an alternate account without disrupting the
  stored configuration of your main account.
* **New flag** `--dev`, for enabling development-branch sub-repositories.
  This adds support for easily requesting `dev` modules from LuaRocks.org, as in:
  `luarocks install --dev luafilesystem`. The list of URLs configured
  in `rocks_servers` is prepended with a list containing "/dev" in their paths.
* `luarocks config`, when called with no arguments, now displays your
  entire active configuration, using the same Lua syntax as the configuration
  file. It is sensitive to the flags given to it (`--tree`, `--lua-dir`, etc.)
  so it presents the resulting configuration produced by loading the
  currently-active configuration files and the given flags.

### New build system

**New build system**: the `configure` and `Makefile` scripts were completely
overhauled, making use of LuaRocks 3 features to greatly simplify them:

* Much of the detection and configuration work they performed were moved
  to runtime, to make LuaRocks more dynamic and resilient to environment
  changes
* The system-package-manager-friendly mode is still available, as the
  default target (`make`, formerly `make build`).
* The LuaRocks-as-a-rock mode (`make bootstrap`) is also still available,
  and was greatly simplified: it no longer uses custom Makefiles:
  LuaRocks installs itself using `luarocks make`, and its own rockspec
  uses the `builtin` build mode.
* A new build mode: `make binary` compiles all of LuaRocks into a single
  executable, bundling various Lua modules to make it self-sufficient,
  such as LuaFileSystem, LuaSocket and LuaSec.
  * For version 3.0, this will remain as an option, as we evaluate
    its suitability moving forward to become the default mode of
    distribution.
  * The goal is to eventually use this mode to produce the Windows
    version of LuaRocks. We currently include an experimental
    `make windows-binary` target which builds a Windows version
    using the MinGW-w64 cross-compiler on Linux.

### General improvements

* **New feature:** [namespaces](https://github.com/luarocks/luarocks/wiki/Namespaces):
  you can use `luarocks install user/package` to install a package from a
  specific user of the repository.
* Improved defaults for finding external libraries on Linux and Windows.
* Detection of the Lua library and header directories is now done at runtime.
  This uses the same machinery that LuaRocks employs for `external_dependencies`
  in general (with some added logic to cope with the unfortunate
  rampant inconsistency in naming of Lua libraries and header paths
  due to lack of upstream standardization).
* `luarocks-admin add` now works with `file://` repositories
* some UI improvements in `luarocks list` and `luarocks search`.
* Preliminary support for the upcoming Lua 5.4: LuaRocks is written in
  the common dialect supporting Lua 5.1-5.3 and LuaJIT, but since a
  single installation can manage packages for any Lua version now,
  it can already manage packages for Lua 5.4 even though that's not
  out yet.

### User-visible changes

* **Breaking change:** The support for deprecated unversioned paths
  (e.g. `/usr/local/lib/luarocks/rocks/` and `/etc/luarocks/config.lua`)
  was removed, LuaRocks will now only create and use paths versioned
  to the specific Lua version in use
  (e.g. `/usr/local/lib/luarocks/rocks-5.3/` and `/etc/luarocks/config-5.3.lua`).
* **Breaking changes:** `luarocks path` now exports versioned variables
  `LUA_PATH_5_x` and `LUA_CPATH_5_x` instead of `LUA_PATH` and `LUA_CPATH`
  when those are in use in your system.
* Package paths are sanitized to only reference the current Lua version.
  For example, if you have `/some/dir/lua/5.1/` in your `$LUA_PATH` and
  you are running Lua 5.2, `luarocks.loader` and the `luarocks` command-line
  tool will convert it to `/some/dir/lua/5.2/`.
* LuaRocks now uses `dev` instead of `scm` as the favored version identifier
  to describe development versions of a rock, aligning it with the terminology
  used in https://luarocks.org. It still understands `scm` as a
  compatibility fallback.
* LuaRocks no longer conflates modules `foo` and `foo.init` as being the
  same in its internal manifest. Instead, the `luarocks.loader` module
  is adapted to handle the `.init` case.
* Wrappers installed using `--tree` now prepend the tree's prefix to their
  package paths.
* `luarocks-admin` commands no longer creates an `index.html` file in the
  repository by default (it does update it if it already exists)

### Internal changes

* Major improvements in the test suite done by @georgeroman as part of the ongoing
  Google Summer of Code 2018 program. The coverage improvements and test suite
  speed-ups have been essential in getting the sprint towards LuaRocks 3.0 more
  efficient and reliable!
* Modules needed by `luarocks.loader` were moved below the `luarocks.core` namespace.
  Modules in `luarocks.core` only depend on other `luarocks.core` modules.
  (Notably, `luarocks.core` does not use `luarocks.fs`.)
* Modules representing `luarocks` commands were moved into the `luarocks.cmd` namespace,
  and `luarocks.command_line` was renamed to `luarocks.cmd`. Eventually, all CLI-related
  code will live under `luarocks.cmd`, as we move towards a clean CLI-API separation,
  in preparation for a stable public API.
* Likewise, modules representing `luarocks-admin` commands were moved into the
  `luarocks.admin.cmd` namespace.
* New internal objects for representing interaction with the repostories:
  `luarocks.queries` and `luarocks.results`
* Type checking rules of file formats were moved into the `luarocks.type` namespace.



## LuaRocks 2.4.4

> Released 12/Mar/2018

* Do not halt a package deletion process when a file from the package is missing
* Updated bundled binaries in Windows package: Lua 5.1.5, Wget 1.19.4, 7zip 18.01
* Updated Windows installer to better handle gcc toolchains
* Fix detection of directories on Windows
* Fixes .def generation on Windows


## LuaRocks 2.4.3

> Released 12/Sep/2017

* Fixed display of pathnames in `luarocks show`
* Improved check for write permissions when installing
* Plus assorted bugfixes and improvements


## LuaRocks 2.4.2

> Released 30/Nov/2016

* Fixed conflict resolution on deploy/delete
* Improved dependency check messages
* Performance improvements when removing packages
* Support user-defined `platforms` array in config file
* Improvements in Lua interpreter version detection in Unix configure script
* Relaxed Lua version detection to improve support for alternative implementations (e.g. Ravi)
* Plus assorted bugfixes and improvements


## LuaRocks 2.4.1

> Released 06/Oct/2016

* Avoid coroutine use in luarocks.loader
* Fix upgrade issues for very old versions


## LuaRocks 2.4.0

> Released 08/Sep/2016

* New test suite based on Busted; runs on Linux, OSX and Windows
* git+ssh:// fetch protocol
* Improved behavior preserving permissions
* Improved listing of dependencies on installation
* Improved behavior of argument handling in `pack`
* MSYS and Haiku platform detection
* Feature-based detection of internal bit32 and utf8 modules
* Internal reorganization of luarocks.fs code
* `remove` option --force=fast renamed to --force-fast
* Plus assorted bugfixes and cleanups


## LuaRocks 2.3.0

> Released 09/Jan/2016

* Windows: major redesign of the install tree structure
* Windows: Auto setup of MSVC environments
* Improve error messages when tools are not installed
* CMake: generate 64-bit builds when appropriate
* Improve check of location of config files
* MacOSX: set MACOSX_DEPLOYMENT_TARGET using env
* Remove --extensions flag; use rockspec_format instead
* New `luarocks config` command to query configuration
* Improved UI for messages when external deps are missing
* Unix: Robustness improvement in configure script
* Plus tweaks and bugfixes. See the changelog for details.


## LuaRocks 2.2.2

> Released 24/Apr/2015

* `luarocks build --only-deps` and `luarocks install --only-deps` for installing dependencies only
* Mercurial support
* Improved command-line argument parser, now validates arguments (it previously ignored unrecognized arguments) and accepts both `--flag=option` and `--flag option` in flags that take arguments.
* For consistency with `luarocks show`, `luarocks doc --homepage` is now `luarocks doc --home`
* Improvements to CMake build backend
* Improved Makefiles for handling simultaneous bootstrapped installations
* Various bugfixes


## LuaRocks 2.2.1

> Released 17/Mar/2015

* Improved compatibility with Lua 5.3
* `luarocks list --outdated` for listing modules with available upgrades
* Assorted bugfixes


## LuaRocks 2.2.0

> Released 15/Aug/2014

* MoonRocks is the new default repository: http://rocks.moonscript.org - Rocks don't need to be sent to the LuaRocks mailing list anymore, you can upload them directly at the website or using...
* ...`luarocks upload` command for uploading rocks to MoonRocks via the command-line
* Preliminary support for Lua 5.3
* No longer uses the module() function, for Lua 5.2 installations built without Lua 5.1 compatibility
* --branch flag for `luarocks build` and `luarocks make`
* various improvements in `luarocks doc` command
* "git+http" transport for source.url


## LuaRocks 2.1.2

> Released 10/Jan/2014

* major improvements in the Windows install.bat script. Now installs by default on standard Windows locations, while the old self-contained all-under-one-dir installation is still supported through an option flag. The documentation at luarocks.org didn't catch up with it yet, so please refer to "install /?" for instructions.
* a new command, "luarocks doc <module>" that tries to find any installed documentation. Due to the lack of documentation standards for Lua, this uses a few heuristics. Feedback on the feature is appreciated.
* a rocks_provided configuration entry in which you can preload dependencies that are already fulfulled in your system; a few defaults are included (bit32 is auto-provided in Lua 5.2; luabitop is auto-provided in LuaJIT)
* generated script wrappers are now more robust
* Graceful handling of permission errors on Windows
* Minor performance improvements
* Support for "named trees", so you can label your rocks trees and use flags such as --tree=system  or --tree=user instead of the full path
* "luarocks" with no arguments presents more useful diagnostics
* Improved Lua detection in Unix installer
* plus assorted bugfixes


## LuaRocks 2.1.1

> Released 29/Oct/2013

* Remote manifests are now compressed and locally cached, making commands faster
* New command "write_rockspec" which generates rockspec file templates
* detection of multiarch directories on Linux
* environment and performance improvements on Windows
* New --force=fast option for `luarocks remove`
* New --local-tree flag for `luarocks-admin make-manifest`
* Improved error checking
* plus assorted bugfixes


## LuaRocks 2.1.0

> Released 09/Aug/2013

* accesses manifest-{5.1,5.2} in remote servers to provide properly filtered results for Lua 5.1 or 5.2
* Remove old versions when installing a new one and old versions are no longer needed to honor dependencies.
* `make bootstrap` is now an advertised option for installing LuaRocks itself as a rock on Unix systems
* `luarocks purge --old-versions` for cleaning up a local tree
* --keep flag to produce the old behavior of keeping old versions around (can be made permanent setting keep_old_versions=true in the config file)
* security config options `accepted_build_types` and `hooks_enabled`
* `lua_version` is now available as a global for your config.lua
* new flags --lr-path, --lr-cpath, --lr-bin for `luarocks path` for use in scripts
* friendlier error messages
* plus bugfixes


## LuaRocks 2.0.13

> Released 16/Apr/2013

* Support for Lua 5.2 is no longer marked as experimental
* Support for installing two instances of LuaRocks, for Lua 5.1 and 5.2, in parallel
* Improvements for the `builtin` build mode on Windows
* rclauncher on Windows does not rely on a precompiled object anymore
* Improvements for the Windows installer, including optional registry entries for context-menu operations
* Improvements in `luarocks new_version` command for autogenerating updated rockspecs
* `luarocks remove` command accepts rock and rockspec filenames


## LuaRocks 2.0.12

> Released 05/Nov/2012

* "Dependencies mode" selection to configure how to work with multiple local trees
* New command "purge" that erases a local tree
* --porcelain flag for "list" and "search"
* More consistent user-agent reporting
* Code cleanups, removal of dead code
* Fixes regressions on Mac and Windows


## LuaRocks 2.0.11

> Released 21/Sep/2012

* Work around LuaSocket crash when given proxy URLs without the scheme part
* Save manifest file in a single fs operation to make it more atomic
* Fix tree loading order on luarocks.loader with multiple trees
* Fix detection of write permissions
* Improve dependency detection using configurable patterns, now a file like "libfoo.so.1" satisfies "libfoo.so"
* --bin flag for "luarocks path" command, exports $PATH
* Support for mirrors in the rocks_servers list, default list of mirrors included
* Avoid using Lua modules internally on Windows, to avoid file system locking
* Add NetBSD support
* Rename luarocks.rep to luarocks.repos
* Fail gracefully on the absence of cmake, on cmake build mode
* New command "lint", to check the syntax of a rockspec
* Fix builtin build mode on Mac OSX < 10.5
* Improve configure tests for Debian-based platforms


## LuaRocks 2.0.10

> Released 12/Jul/2012

* Fix fetching Git tags/branches
* Fix strictness issue with parameter of io.open
* Builtin mode sets rpath when compiling on Unix
* Use full path in $(LUA) when configured with --with-lua
* Cleanup of .svn dir in svn-based rocks
* Improvement for `make bootstrap`


## LuaRocks 2.0.9

> Released 31/May/2012

* Experimental support for Lua 5.2 (auto-detection and explicit --lua-version flag in configure)
* Solaris support and BSD fixes
* --nodeps flag for forced installation without dependencies
* "new_version" command to streamline writing of updated rockspecs
* Improved handling of LUAROCKS_SYSCONFIG variable
* Clickable URLs in descriptions in rocks repo index.html
* Nicer-looking persisted tables
* Assorted bugfixes


## LuaRocks 2.0.8

> Released 29/Feb/2012

* Fix in CMake build backend
* Fix handling error condition of --pack-binary-rock
* Fixes for Windows .bat installer
* Improved arch detection when packing binary rocks
* Workaround LuaPosix 5.1.15 problem with chmod()
* Proper error messages when config files are invalid
* Avoid checking permissions when it's not necessary
* Fix behavior of `builtin` rocks which install init.lua scripts
* git+file:// pseudoprotocol for local Git repos
* New binaries from GnuWin32 shipped in Win32 zip
* Nicer-looking help


## LuaRocks 2.0.7.1

> Released 10/Jan/2012

* Fix installation of files in build operation
* Deprecate --to and --from, use --server and --tree instead
* Improved documentation, thanks to LDoc


## LuaRocks 2.0.7

> Released 10/Dec/2011

* Quieter git checkout
* --only-sources flag to restrict download of sources from a single domain
* Copy entries to bin/ with proper permissions
* Fix --pack-binary-rock and add support for it in "luarocks make" as well
* Isolate references to "5.1" to luarocks.cfg module
* More logical names for flags: --tree, --server
* Improved documentation


## LuaRocks 2.0.6

> Released 04/Oct/2011

* Fixes for rockspecs missing `description` or the contents of `source.url`
* Escape fixes for LuaJIT/Metalua
* Support for building a rock without installing it
* Site-local configuration is now at luarocks.site_config
* Support for Mercurial
* Flag for experimental extensions
* Plus assorted bugfixes


## LuaRocks 2.0.5

> Released 17/Aug/2011

* External commands are overridable through variables or config.lua
* No longer uses print() - output goes to stdout, errors to stderr
* Handle redirects between http (LuaSocket) and https (LuaSec)
* Avoid relying on the $PWD variable
* Code cleanups


## LuaRocks 2.0.4.1

> Released 17/Jan/2011

* Minor bugfix release


## LuaRocks 2.0.4

> Released 23/Dec/2010

* Command "remove" for luarocks-admin
* Check for write permissions in repository and suggest --local
* Remove .git from source tree when downloading from Git
* Display of external dependencies in index.html
* OpenBSD support
* More thorough search for external libraries
* Normalize paths to fix behavior when LFS is used under Windows
* Add HTTPS support using LuaSec when using LuaSocket, for consistency
* Better propagation of error messages
* Stable sort of persisted files such as manifests
* Plus assorted bugfixes


## LuaRocks 2.0.3

> Released 14/Sep/2010

* Check for permissions and warn user instead of just installing in local tree
* --local flag for operations on the local tree
* -fPIC is always set in CFLAGS exported to makefiles
* respect permissions when copying files in Unix systems
* display license after build/installation
* svn:// protocol for scm rockspecs
* "luarocks list" and "luarocks search" are now case-insensitive
* "luarocks-admin add" supports adding multiple files at once
* "luarocks-admin add" supports rsync for download and upload and scp for upload
* new command: "luarocks show" displays information about an installed rock
* new command: "luarocks path" to make it easy to export Lua env variables
* plus assorted bugfixes


## LuaRocks 2.0.2

> Released 01/Apr/2010

* use LuaSocket if available for downloading files
* use LuaZip if available for unzipping files
* MinGW support in builtin build backend
* updated installation files for Windows, including a LuaForWindows-compatible package


## LuaRocks 2.0.1

> Released 27/Oct/2009

* luarocks.cfg is no longer edited during installation; a separate site-local luarocks.config module is created.
* robustness fixes and improvements for luarocks.add
* cleanup of configure options and references to the old LuaForge URLs
* install LuaRocks as a rock
* plus assorted bugfixes


## LuaRocks 2.0

> Released 17/Oct/2009

* module files are now deployed to standard Lua-style paths
* new package loader module luarocks.loader, superseding the require()-override module luarocks.require
* new abstraction system for file system operations: the OS-specific back-ends for luarocks.fs were split between native-Lua and tool-based implementations
* new format for local manifest
* new command for luarocks: "download", to fetch .rock and .rockspec files
* new commands for luarocks-admin: "add", to upload rocks to a repository, and "refresh_cache", to refresh the cache used by the "add" command
* plus a number of cleanups and bugfixes


## LuaRocks 1.0.1

> Released 13/Mar/2009

* Improve portability in usage of Unix tools
* Allow use of local rocks servers in the --from flag
* Improve detection of external libraries on Mac OSX
* Fix build of the `builtin` backend under Windows
* Support for the `md5` binary as a MD5 checker


## LuaRocks 1.0

> Released 01/Sep/2008

* Add support for post-install hooks
* Path helper scripts for binaries on Windows systems.
* Git support, contributed by Thomas Harning.
* Improve shell compatibility for different Unix systems.
* Add the @ operator for no-upgrade dependencies.
* Add check for rockspec version format.
* Generate index.html when building a manifest for a repository.
* Plus assorted bugfixes.


## LuaRocks 0.6

> Released 30/Jun/2008

* Check external deps on binary installs. Allow rockspecs to specify supported platforms. Support platform-agnostic specification of external deps files.  Allow overriding external deps subdirs.
* Structured build systems in subdirectories.
* Smarter check to decide if a rock is pure Lua or not, also checking bin/
* Restructuring of fs code.
* Modularized fetch code to support multiple SCMs.
* Added specific support for `doc` directory in rockspecs. Auto-install files in `lua` in builtin builds.
* Support for Surround SCM, contributed by Ignacio Burgueño.
* "module" build type renamed to "builtin"; "cvs_tag" and "cvs_module" renamed to "tag" and "module". Old names still supported for compatibility for now, to be cleaned up by 1.0.
* Plus many bugfixes.


## LuaRocks 0.5.2

> Released 13/May/2008

* Fixes problems with removal of read-only files on Windows
* Fixes issues with external libraries on the `module` build type on Windows
* Fixes the --only-from flag
* Renames the luarocks.config module to luarocks.cfg avoiding conflict's with the user configuration file config.lua


## LuaRocks 0.5.1

> Released 25/Apr/2008

* Added function get_rock_from_module in luarocks.require, allowing apps to inspect which rock they're getting modules from.
* Added variables LUA, LIB_EXTENSION and OBJ_EXTENSION, now available for rockspec authors.
* Assorted bugfixes, especially for the Windows package.
* Build system improvements: add DESTDIR variable to makefile to make things easier for distros packaging LuaRocks.


## LuaRocks 0.5

> Released 03/Apr/2008

* New flags in the ./configure on Unix (see configure --help) and install.bat on Windows (see install.bat /?)
* Support for multiple local repositories. By extension, LuaRocks features more intuitive configuration defaults (it installs rocks to $PREFIX/lib/luarocks if you have the permission, and to $HOME/.luarocks if you don't).
* Flags --from=_server_, --only-from=_server_ and --to=_tree_, to allow specifying exactly where to get rocks from and where to install them to.
* The manifest file now stores dependency info -- luarocks.require no longer scans rockspec files.
* `unpack` command allows unpacking binary and pure-Lua rocks, for inspecting.
* Plus assorted bugfixes.


## LuaRocks 0.4.3

> Released 03/Mar/2008

* The MD5 check feature added in 0.4.2 can now use openssl instead of md5sum (making LuaRocks friendlier to OSX).
* Added a license file in the tarball (making LuaRocks friendlier to Debian).
* Plus assorted bugfixes.


## LuaRocks 0.4.2

> Released 09/Feb/2008

* Support .lua files directly in the URL field.
* Perform check of MD5 checksum in sources.
* Accept plain strings in all fields of the source table of the "module" build type.
* Bugfixes.


## LuaRocks 0.4.1

> Released 25/Jan/2008

* New configure/install.bat flags for setting scripts dir and local repository dir.
* "unpack" command now supports rockspec files as well.
* Complete code documentation.
* Many assorted bugfixes.


## LuaRocks 0.4

> Released 18/Jan/2008

* Adds the "unpack" command for debugging rocks (.src.rock only at this point).
* Support curl as an alternative downloader for OSX, removing the dependency on wget.
* Support for installing non-Lua entries in bin/ dirs.
* Support for specifying libdirs, incdirs, libraries and defines in "module"-type builds.
* x86_64 support, by Brian Hetro.
* FreeBSD support, by Matthew M. Burke.
* Performance improvements.
* Many assorted bugfixes.


## LuaRocks 0.3.2

> Released 21/Dec/2007

* Support for patching and inclusion of extra files (such as Makefiles) through a rockspec.
* Support "platforms" overrides table for dependencies, external dependencies and source URLs.
* Many assorted bugfixes.


## LuaRocks 0.3.1

> Released 18/Dec/2007

* Improved search: results now feature separate lists for source and binary rocks.
* Windows support for the "module" build type (using Visual Studio).
* Many assorted bugfixes.


## LuaRocks 0.3

> Released 04/Dec/2007

* Includes Windows package.
* Adds the "module" build type.
* Performance improvements.


## LuaRocks 0.2

> Released 23/Oct/2007

* Bugfixes and improvements to build infrastructure.
* Adds the LuaRocks "remove" command.


## LuaRocks 0.1

> Released 09/Aug/2007

* Initial release.
