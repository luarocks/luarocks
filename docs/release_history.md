# Release history

**Version 3.11.1** - 31/May/2024 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.11.1.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.11.1-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.11.1-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.11.1-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.11.0** - 13/Mar/2024 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.11.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.11.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.11.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.11.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.10.0** - 27/Feb/2024 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.10.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.10.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.10.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.10.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.9.2** - 08/Dec/2022 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.9.2.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.9.2-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.9.2-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.9.2-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.9.1** - 01/Jul/2022 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.9.1.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.9.1-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.9.1-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.9.1-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.9.0** - 17/Apr/2022 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.9.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.9.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.9.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.9.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

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

**Version 3.8.0** - 08/Nov/2021 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.8.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.8.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.8.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.8.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.7.0** - 13/Apr/2021 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.7.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.7.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.7.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.7.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.6.0** - 30/Mar/2021 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.6.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.6.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.6.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.6.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.5.0** - 10/Dec/2020 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.5.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.5.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.5.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.5.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.4.0** - 25/Sep/2020 - [Source tarball for Unix](http://luarocks.org/releases/luarocks-3.4.0.tar.gz) -
[Windows binary (32-bit)](http://luarocks.org/releases/luarocks-3.4.0-windows-32.zip) -
[Windows binary (64-bit)](http://luarocks.org/releases/luarocks-3.4.0-windows-64.zip) -
[Linux binary (x86_64)](http://luarocks.org/releases/luarocks-3.4.0-linux-x86_64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

* `luarocks make` now supports `--only-deps`
* `luarocks make` new flag: `--no-install`, which only performs the compilation step
* `--deps-only` is now an alias for `--only-deps` (useful in case you always kept getting it wrong, like me!)
* `luarocks build` and `luarocks make` now support using `--pin` and `--only-deps` at the same time, to produce a lock file of dependencies in use without installing the main package.
* `luarocks show` can now accept a substring of the rock's name, like `list`.
* `luarocks config`: when running without system-wide permissions, try storing the config locally by default. Also, if setting both lua_dir and --lua-version explicitly, auto-switch the default Lua version.
* `luarocks` with no arguments now prints more info about the location of the Lua interpreter which is being used
* `luarocks new_version` now keeps the old URL if the MD5 doesn't change.
* `DEPS_DIR` is now accepted as a generic variable for dependency directories (e.g. `luarocks install foo DEPS_DIR=/usr/local`)
* Handle quoting of arguments at the application level, for improved Windows support
* All-in-one binary bundles `dkjson`, so it runs `luarocks upload` without requiring any additional dependencies.
* Tweaks for Terra compatibility
* win32: generate proper temp filename
* No longer assume that Lua 5.3 is built with compat libraries and bundles `bit32`
* `luarocks show`: do not crash when rockspec description is empty
* When detecting the location of `lua.h`, check that its version matches the version of Lua being used
* Fail gracefully when a third-party tool (wget, etc.) is missing
* Fix logic for disabling mirrors that return network errors
* Fix detection of Lua path based on arg variable
* Fix regression on dependency matching of luarocks.loader

**Version 3.3.1** - 07/Feb/2020 - [All Unix](http://luarocks.org/releases/luarocks-3.3.1.tar.gz) -
[Windows all-in-one executable (32-bit)](http://luarocks.org/releases/luarocks-3.3.1-windows-32.zip) -
[Windows all-in-one executable (64-bit)](http://luarocks.org/releases/luarocks-3.3.1-windows-64.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

* Fix downgrades of rocks containing directories: stop it from creating spurious 0-byte files where directories have been
* Fix error message when attempting to copy a file that is missing
* Detect OpenBSD-specific dependency paths

**Version 3.3.0** - 28/Jan/2020 - [All Unix](http://luarocks.org/releases/luarocks-3.3.0.tar.gz) -
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.3.0-windows-32.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.2.1** - 05/Sep/2019 - [All Unix](http://luarocks.org/releases/luarocks-3.2.1.tar.gz) -
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.2.1-windows-32.zip) -
[other files](http://luarocks.github.io/luarocks/releases)

**Version 3.2.0** - 28/Aug/2019 - [All Unix](http://luarocks.org/releases/luarocks-3.2.0.tar.gz) -
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.2.0-windows-32.zip) - [other files](https://luarocks.github.io/luarocks/releases)

* Bugfix: luarocks path does not change the order of pre-existing path items when prepending or appending to path variables
* Bugfix: fix directory detection on the Mac
* When building with --force-config, LuaRocks now never uses the "project" directory, but only the forced configuration
* Lua libdir is now only checked for commands/platforms that really need to link Lua explicitly
* LuaJIT is now detected dynamically
* RaptorJIT is now detected as a LuaJIT variant
* Improvements in Lua autodetection at runtime
* luarocks new_version: new option --dir
* luarocks which: report modules found via package.path and package.cpath as well
* install.bat: Improved detection for Visual Studio 2017 and higher
* Bundled LuaSec in all-in-one binary bumped to version 0.8.1

**Version 3.1.3** - 06/Jun/2019 - [All Unix](http://luarocks.org/releases/luarocks-3.1.3.tar.gz) -
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.1.3-windows-32.zip)

**Version 3.1.2** - 07/May/2019 - [All Unix](http://luarocks.org/releases/luarocks-3.1.2.tar.gz) -
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.1.2-windows-32.zip)

**Version 3.1.1** - 06/May/2019 - [All Unix](http://luarocks.org/releases/luarocks-3.1.1.tar.gz) -
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.1.1-windows-32.zip)

**Version 3.1.0** - 30/Apr/2019 - [All Unix](http://luarocks.org/releases/luarocks-3.1.0.tar.gz) - 
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.1.0-windows-32.zip)

* config: add git-like modes for setting and inspecting configuration
* make: run rockspec patches on first `luarocks make` run and use a lockfile to avoid double patching
* persist selected Lua version when setting `luarocks config lua_version 5.x`
* new flag --global for overriding local_by_default = true
* do not complain if home cache cannot be created (use temp dir instead)
* caching improvements for increased performance
* project-based workflow: if ./.luarocks/config-5.x.lua exists, assume Lua 5.x
* install, pack, build, make: new flags --sign and --verify (using GPG)
* install: new flag --no-doc
* Improve Lua paths auto-detection
* Various bugfixes

**Version 3.0.4** - 30/Oct/2018 - [All Unix](http://luarocks.org/releases/luarocks-3.0.4.tar.gz) - 
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.0.4-windows-32.zip)

* Fork-free platform detection at startup
* Improved detection of the default rockspec in commands such as `luarocks test`
* Various minor bugfixes

**Version 3.0.3** - 15/Sep/2018 - [All Unix](http://luarocks.org/releases/luarocks-3.0.3.tar.gz) - 
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.0.3-windows-32.zip)

* Minor bugfixes

**Version 3.0.2** - 07/Sep/2018 - [All Unix](http://luarocks.org/releases/luarocks-3.0.2.tar.gz) - 
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.0.2-windows-32.zip)

* Improvements in luarocks init, new --reset flag
* write_rockspec: --lua-version renamed to --lua-versions
* Improved behavior in module autodetection
* Bugfixes in luarocks show
* Fix upgrade/downgrade when a single rock has clashing module filenames
* Fix for autodetected external dependencies with non-alphabetic characters

**Version 3.0.1** - 14/Aug/2018 - [All Unix](http://luarocks.org/releases/luarocks-3.0.1.tar.gz) - 
[Windows all-in-one executable](http://luarocks.org/releases/luarocks-3.0.1-windows-32.zip)

* Numerous bugfixes
* Store Lua location in config file, so that a user can run `luarocks init --lua-dir=/my/lua/location` and have that location remain active for that project
* Various improvements to the Unix makefile, including $(DESTDIR) support and an uninstall rule
* Autodetect FreeBSD-style include paths (/usr/include/lua5x/)

**Version 3.0.0** - 25/Jul/2018 - [All Unix](http://luarocks.org/releases/luarocks-3.0.0.tar.gz) - 
[Windows batch installer](http://luarocks.org/releases/luarocks-3.0.0-win32.zip)

* New rockspec format
* New commands, including `luarocks init` for per-project workflows
* New flags, including `--lua-dir` and `--lua-version` for using multiple Lua installs with a single LuaRocks
* New build system, gearing towards a new distribution model
* General improvements, including namespaces
* User-visible changes, including some breaking changes
* Internal changes

**Version 2.4.4** - 12/Mar/2018 - [All Unix](http://luarocks.org/releases/luarocks-2.4.4.tar.gz) - 
[Windows](http://luarocks.org/releases/luarocks-2.4.4-win32.zip)

* Do not halt a package deletion process when a file from the package is missing
* Updated bundled binaries in Windows package: Lua 5.1.5, Wget 1.19.4, 7zip 18.01
* Updated Windows installer to better handle gcc toolchains
* Fix detection of directories on Windows
* Fixes .def generation on Windows

**Version 2.4.3** - 12/Sep/2017 - [All Unix](http://luarocks.org/releases/luarocks-2.4.3.tar.gz) - 
[Windows](http://luarocks.org/releases/luarocks-2.4.3-win32.zip)

* Fixed display of pathnames in `luarocks show`
* Improved check for write permissions when installing
* Plus assorted bugfixes and improvements

**Version 2.4.2** - 30/Nov/2016 - [All Unix](http://luarocks.org/releases/luarocks-2.4.2.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.4.2-win32.zip)

* Fixed conflict resolution on deploy/delete
* Improved dependency check messages
* Performance improvements when removing packages
* Support user-defined `platforms` array in config file
* Improvements in Lua interpreter version detection in Unix configure script
* Relaxed Lua version detection to improve support for alternative implementations (e.g. Ravi)
* Plus assorted bugfixes and improvements

**Version 2.4.1** - 06/Oct/2016 - [All Unix](http://luarocks.org/releases/luarocks-2.4.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.4.1-win32.zip)

* Avoid coroutine use in luarocks.loader
* Fix upgrade issues for very old versions

**Version 2.4.0** - 08/Sep/2016 - [All Unix](http://luarocks.org/releases/luarocks-2.4.0.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.4.0-win32.zip)

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

**Version 2.3.0** - 09/Jan/2016 - [All Unix](http://luarocks.org/releases/luarocks-2.3.0.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.3.0-win32.zip)

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

**Version 2.2.2** - 24/Apr/2015 - [All Unix](http://luarocks.org/releases/luarocks-2.2.2.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.2.2-win32.zip)

* `luarocks build --only-deps` and `luarocks install --only-deps` for installing dependencies only
* Mercurial support
* Improved command-line argument parser, now validates arguments (it previously ignored unrecognized arguments) and accepts both `--flag=option` and `--flag option` in flags that take arguments.
* For consistency with `luarocks show`, `luarocks doc --homepage` is now `luarocks doc --home`
* Improvements to CMake build backend
* Improved Makefiles for handling simultaneous bootstrapped installations
* Various bugfixes

**Version 2.2.1** - 17/Mar/2015 - [All Unix](http://luarocks.org/releases/luarocks-2.2.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.2.1-win32.zip)

* Improved compatibility with Lua 5.3
* `luarocks list --outdated` for listing modules with available upgrades
* Assorted bugfixes

**Version 2.2.0** - 15/Aug/2014 - [All Unix](http://luarocks.org/releases/luarocks-2.2.0.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.2.0-win32.zip)

* MoonRocks is the new default repository: http://rocks.moonscript.org - Rocks don't need to be sent to the LuaRocks mailing list anymore, you can upload them directly at the website or using...
* ...`luarocks upload` command for uploading rocks to MoonRocks via the command-line
* Preliminary support for Lua 5.3
* No longer uses the module() function, for Lua 5.2 installations built without Lua 5.1 compatibility
* --branch flag for `luarocks build` and `luarocks make`
* various improvements in `luarocks doc` command
* "git+http" transport for source.url

**Version 2.1.2** - 10/Jan/2014 - [All Unix](http://luarocks.org/releases/luarocks-2.1.2.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.1.2-win32.zip)

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

**Version 2.1.1** - 29/Oct/2013 - [All Unix](http://luarocks.org/releases/luarocks-2.1.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.1.1-win32.zip)

* Remote manifests are now compressed and locally cached, making commands faster
* New command "write_rockspec" which generates rockspec file templates
* detection of multiarch directories on Linux
* environment and performance improvements on Windows
* New --force=fast option for 'luarocks remove'
* New --local-tree flag for 'luarocks-admin make-manifest'
* Improved error checking
* plus assorted bugfixes

**Version 2.1.0** - 09/Aug/2013 - [All Unix](http://luarocks.org/releases/luarocks-2.1.0.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.1.0-win32.zip)

* accesses manifest-{5.1,5.2} in remote servers to provide properly filtered results for Lua 5.1 or 5.2
* Remove old versions when installing a new one and old versions are no longer needed to honor dependencies.
* 'make bootstrap' is now an advertised option for installing LuaRocks itself as a rock on Unix systems
* 'luarocks purge --old-versions' for cleaning up a local tree
* --keep flag to produce the old behavior of keeping old versions around (can be made permanent setting keep_old_versions=true in the config file)
* security config options 'accepted_build_types' and 'hooks_enabled'
* 'lua_version' is now available as a global for your config.lua
* new flags --lr-path, --lr-cpath, --lr-bin for 'luarocks path' for use in scripts
* friendlier error messages
* plus bugfixes

**Version 2.0.13** - 16/Apr/2013 - [All Unix](http://luarocks.org/releases/luarocks-2.0.13.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.13-win32.zip)

* Support for Lua 5.2 is no longer marked as experimental
* Support for installing two instances of LuaRocks, for Lua 5.1 and 5.2, in parallel
* Improvements for the 'builtin' build mode on Windows
* rclauncher on Windows does not rely on a precompiled object anymore
* Improvements for the Windows installer, including optional registry entries for context-menu operations
* Improvements in 'luarocks new_version` command for autogenerating updated rockspecs
* 'luarocks remove' command accepts rock and rockspec filenames

**Version 2.0.12** - 05/Nov/2012 - [All Unix](http://luarocks.org/releases/luarocks-2.0.12.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.12-win32.zip)

* "Dependencies mode" selection to configure how to work with multiple local trees
* New command "purge" that erases a local tree
* --porcelain flag for "list" and "search"
* More consistent user-agent reporting
* Code cleanups, removal of dead code
* Fixes regressions on Mac and Windows

**Version 2.0.11** - 21/Sep/2012 - [All Unix](http://luarocks.org/releases/luarocks-2.0.11.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.11-win32.zip)

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

**Version 2.0.10** - 12/Jul/2012 - [All Unix](http://luarocks.org/releases/luarocks-2.0.10.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.10-win32.zip)

* Fix fetching Git tags/branches 
* Fix strictness issue with parameter of io.open
* Builtin mode sets rpath when compiling on Unix
* Use full path in $(LUA) when configured with --with-lua
* Cleanup of .svn dir in svn-based rocks
* Improvement for 'make bootstrap'

**Version 2.0.9** - 31/May/2012 - [All Unix](http://luarocks.org/releases/luarocks-2.0.9.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.9-win32.zip)

* Experimental support for Lua 5.2 (auto-detection and explicit --lua-version flag in configure)
* Solaris support and BSD fixes
* --nodeps flag for forced installation without dependencies
* "new_version" command to streamline writing of updated rockspecs
* Improved handling of LUAROCKS_SYSCONFIG variable
* Clickable URLs in descriptions in rocks repo index.html
* Nicer-looking persisted tables
* Assorted bugfixes

**Version 2.0.8** - 29/Feb/2012 - [All Unix](http://luarocks.org/releases/luarocks-2.0.8.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.8-win32.zip)

* Fix in CMake build backend
* Fix handling error condition of --pack-binary-rock
* Fixes for Windows .bat installer
* Improved arch detection when packing binary rocks
* Workaround LuaPosix 5.1.15 problem with chmod()
* Proper error messages when config files are invalid
* Avoid checking permissions when it's not necessary
* Fix behavior of 'builtin' rocks which install init.lua scripts
* git+file:// pseudoprotocol for local Git repos
* New binaries from GnuWin32 shipped in Win32 zip
* Nicer-looking help

**Version 2.0.7.1** - 10/Jan/2012 - [All Unix](http://luarocks.org/releases/luarocks-2.0.7.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.7.1-win32.zip)

* Fix installation of files in build operation
* Deprecate --to and --from, use --server and --tree instead
* Improved documentation, thanks to LDoc

**Version 2.0.7** - 10/Dec/2011 - [All Unix](http://luarocks.org/releases/luarocks-2.0.7.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.7-win32.zip)

* Quieter git checkout
* --only-sources flag to restrict download of sources from a single domain
* Copy entries to bin/ with proper permissions
* Fix --pack-binary-rock and add support for it in "luarocks make" as well
* Isolate references to "5.1" to luarocks.cfg module
* More logical names for flags: --tree, --server
* Improved documentation

**Version 2.0.6** - 04/Oct/2011 - [All Unix](http://luarocks.org/releases/luarocks-2.0.6.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.6-win32.zip)

* Fixes for rockspecs missing 'description' or the contents of 'source.url'
* Escape fixes for LuaJIT/Metalua
* Support for building a rock without installing it
* Site-local configuration is now at luarocks.site_config
* Support for Mercurial
* Flag for experimental extensions
* Plus assorted bugfixes

**Version 2.0.5** - 17/Aug/2011 - [All Unix](http://luarocks.org/releases/luarocks-2.0.5.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.5-win32.zip)

* External commands are overridable through variables or config.lua
* No longer uses print() - output goes to stdout, errors to stderr
* Handle redirects between http (LuaSocket) and https (LuaSec)
* Avoid relying on the $PWD variable
* Code cleanups

**Version 2.0.4.1** - 17/Jan/2011 - [All Unix](http://luarocks.org/releases/luarocks-2.0.4.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.4.1-win32.zip)

* Minor bugfix release

**Version 2.0.4** - 23/Dec/2010 - [All Unix](http://luarocks.org/releases/luarocks-2.0.4.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.4-win32.zip)

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

**Version 2.0.3** - 14/Sep/2010 - [All Unix](http://luarocks.org/releases/luarocks-2.0.3.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.3-win32.zip)

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

**Version 2.0.2** - 01/Apr/2010 - [All Unix](http://luarocks.org/releases/luarocks-2.0.2.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.2-win32.zip)

* use LuaSocket if available for downloading files
* use LuaZip if available for unzipping files
* MinGW support in builtin build backend
* updated installation files for Windows, including a LuaForWindows-compatible package

**Version 2.0.1** - 27/Oct/2009 - [All Unix](http://luarocks.org/releases/luarocks-2.0.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0.1-win32.zip)

* luarocks.cfg is no longer edited during installation; a separate site-local luarocks.config module is created.
* robustness fixes and improvements for luarocks.add
* cleanup of configure options and references to the old LuaForge URLs
* install LuaRocks as a rock
* plus assorted bugfixes

**Version 2.0** - 17/Oct/2009 - [All Unix](http://luarocks.org/releases/luarocks-2.0.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-2.0-win32.zip)

* module files are now deployed to standard Lua-style paths
* new package loader module luarocks.loader, superseding the require()-override module luarocks.require
* new abstraction system for file system operations: the OS-specific back-ends for luarocks.fs were split between native-Lua and tool-based implementations
* new format for local manifest
* new command for luarocks: "download", to fetch .rock and .rockspec files
* new commands for luarocks-admin: "add", to upload rocks to a repository, and "refresh_cache", to refresh the cache used by the "add" command
* plus a number of cleanups and bugfixes

**Version 1.0.1** - 13/Mar/2009 - [All Unix](http://luarocks.org/releases/luarocks-1.0.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-1.0.1-win32.zip)

* Improve portability in usage of Unix tools
* Allow use of local rocks servers in the --from flag
* Improve detection of external libraries on Mac OSX
* Fix build of the 'builtin' backend under Windows
* Support for the 'md5' binary as a MD5 checker

**Version 1.0** - 01/Sep/2008 - [All Unix](http://luarocks.org/releases/luarocks-1.0.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-1.0-win32.zip)

* Add support for post-install hooks
* Path helper scripts for binaries on Windows systems.
* Git support, contributed by Thomas Harning.
* Improve shell compatibility for different Unix systems.
* Add the @ operator for no-upgrade dependencies.
* Add check for rockspec version format.
* Generate index.html when building a manifest for a repository.
* Plus assorted bugfixes.

**Version 0.6** - 30/Jun/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.6.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.6-win32.zip)

* Check external deps on binary installs. Allow rockspecs to specify supported platforms. Support platform-agnostic specification of external deps files.  Allow overriding external deps subdirs.
* Structured build systems in subdirectories.
* Smarter check to decide if a rock is pure Lua or not, also checking bin/
* Restructuring of fs code.
* Modularized fetch code to support multiple SCMs.
* Added specific support for 'doc' directory in rockspecs. Auto-install files in 'lua' in builtin builds.
* Support for Surround SCM, contributed by Ignacio Burgueño.
* "module" build type renamed to "builtin"; "cvs_tag" and "cvs_module" renamed to "tag" and "module". Old names still supported for compatibility for now, to be cleaned up by 1.0.
* Plus many bugfixes.

**Version 0.5.2** - 13/May/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.5.2.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.5.2-win32.zip)

* Fixes problems with removal of read-only files on Windows
* Fixes issues with external libraries on the 'module' build type on Windows
* Fixes the --only-from flag
* Renames the luarocks.config module to luarocks.cfg avoiding conflict's with the user configuration file config.lua

**Version 0.5.1** - 25/Apr/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.5.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.5.1-win32.zip)

* Added function get_rock_from_module in luarocks.require, allowing apps to inspect which rock they're getting modules from.
* Added variables LUA, LIB_EXTENSION and OBJ_EXTENSION, now available for rockspec authors.
* Assorted bugfixes, especially for the Windows package.
* Build system improvements: add DESTDIR variable to makefile to make things easier for distros packaging LuaRocks.

**Version 0.5** - 03/Apr/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.5.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.5-win32.zip)

* New flags in the ./configure on Unix (see configure --help) and install.bat on Windows (see install.bat /?)
* Support for multiple local repositories. By extension, LuaRocks features more intuitive configuration defaults (it installs rocks to $PREFIX/lib/luarocks if you have the permission, and to $HOME/.luarocks if you don't).
* Flags --from=_server_, --only-from=_server_ and --to=_tree_, to allow specifying exactly where to get rocks from and where to install them to.
* The manifest file now stores dependency info -- luarocks.require no longer scans rockspec files.
* 'unpack' command allows unpacking binary and pure-Lua rocks, for inspecting.
* Plus assorted bugfixes.

**Version 0.4.3** - 03/Mar/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.4.3.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.4.3-win32.zip)

* The MD5 check feature added in 0.4.2 can now use openssl instead of md5sum (making LuaRocks friendlier to OSX).
* Added a license file in the tarball (making LuaRocks friendlier to Debian).
* Plus assorted bugfixes.

**Version 0.4.2** - 09/Feb/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.4.2.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.4.2-win32.zip)

* Support .lua files directly in the URL field.
* Perform check of MD5 checksum in sources.
* Accept plain strings in all fields of the source table of the "module" build type.
* Bugfixes.

**Version 0.4.1** - 25/Jan/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.4.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.4.1-win32.zip)

* New configure/install.bat flags for setting scripts dir and local repository dir.
* "unpack" command now supports rockspec files as well.
* Complete code documentation.
* Many assorted bugfixes.

**Version 0.4** - 18/Jan/2008 - [All Unix](http://luarocks.org/releases/luarocks-0.4.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.4-win32.zip)

* Adds the "unpack" command for debugging rocks (.src.rock only at this point).
* Support curl as an alternative downloader for OSX, removing the dependency on wget.
* Support for installing non-Lua entries in bin/ dirs.
* Support for specifying libdirs, incdirs, libraries and defines in "module"-type builds.
* x86_64 support, by Brian Hetro.
* FreeBSD support, by Matthew M. Burke.
* Performance improvements.
* Many assorted bugfixes.

**Version 0.3.2** - 21/Dec/2007 - [All Unix](http://luarocks.org/releases/luarocks-0.3.2.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.3.2-win32.zip)

* Support for patching and inclusion of extra files (such as Makefiles) through a rockspec.
* Support "platforms" overrides table for dependencies, external dependencies and source URLs.
* Many assorted bugfixes.

**Version 0.3.1** - 18/Dec/2007 - [All Unix](http://luarocks.org/releases/luarocks-0.3.1.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.3.1-win32.zip)

* Improved search: results now feature separate lists for source and binary rocks.
* Windows support for the "module" build type (using Visual Studio).
* Many assorted bugfixes.

**Version 0.3** - 04/Dec/2007 - [All Unix](http://luarocks.org/releases/luarocks-0.3.tar.gz) - [Windows](http://luarocks.org/releases/luarocks-0.3-win32.zip)

* Includes Windows package.
* Adds the "module" build type.
* Performance improvements.

**Version 0.2** - 23/Oct/2007 - [All Unix](http://luarocks.org/releases/luarocks-0.2.tar.gz)

* Bugfixes and improvements to build infrastructure.
* Adds the LuaRocks "remove" command.

**Version 0.1** - 09/Aug/2007 - [All Unix](http://luarocks.org/releases/luarocks-0.1.tar.gz)

* Initial release.
