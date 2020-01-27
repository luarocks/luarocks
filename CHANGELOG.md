
## What's new in LuaRocks 3.3.0

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

## What's new in LuaRocks 3.2.0

## What's new in LuaRocks 3.1.3

## What's new in LuaRocks 3.1.2

## What's new in LuaRocks 3.1.1

## What's new in LuaRocks 3.1.0

## What's new in LuaRocks 3.0.4

## What's new in LuaRocks 3.0.3

## What's new in LuaRocks 3.0.2

## What's new in LuaRocks 3.0.1

## What's new in LuaRocks 3.0.0

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
