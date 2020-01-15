<p align="center"><a href="http://luarocks.org"><img border="0" src="http://luarocks.github.io/luarocks/luarocks.png" alt="LuaRocks" width="500px"></a></p>

A package manager for Lua modules.

[![Build Status](https://travis-ci.org/luarocks/luarocks.svg?branch=master)](https://travis-ci.org/luarocks/luarocks)
[![Build Status](https://ci.appveyor.com/api/projects/status/4x4630tcf64da48i/branch/master?svg=true)](https://ci.appveyor.com/project/hishamhm/luarocks/branch/master)
[![Coverage Status](https://codecov.io/gh/luarocks/luarocks/coverage.svg?branch=master)](https://codecov.io/gh/luarocks/luarocks/branch/master)
[![Join the chat at https://gitter.im/luarocks/luarocks](https://badges.gitter.im/luarocks/luarocks.svg)](https://gitter.im/luarocks/luarocks)

## LuaRocks3 features
#### LUAROCKS TEST
1. If you use another Lua testing tool, you can create your own test backend.
2. test.type = "foo" will load luarocks.test.foo
3. You can load your test module (or any other test-only depnedencies) using the new test_dependencies block.
                    test_dependencies = {
                        “luacov > 0.1”,
                        “my_custom_testing_tool”,
                          }
#### NEW ROCKSPEC FORMAT
1. First, a word about compatibilty
   a. Format 1.0 frozen since 1.0 (2008)
   b. LR3 assumes 1.0 by default
   c. rockspec_format = "3.0"
2. Improvements in builtin build
   a. Less boilerplate to use the builtin build type
   b. Nearly 80% of rockspecs in luarocks.org use builtin!
   c. build.modules are autodetected if not specified.

Main website: [luarocks.org](http://www.luarocks.org)

It allows you to install Lua modules as self-contained packages called
[*rocks*][1], which also contain version [dependency][2] information. This
information can be used both during installation, so that when one rock is
requested all rocks it depends on are installed as well, and also optionally
at run time, so that when a module is required, the correct version is loaded.
LuaRocks supports both local and [remote][3] repositories, and multiple local
rocks trees.

## Installing

* [Installation instructions for Unix](http://luarocks.org/en/Installation_instructions_for_Unix) (Linux, BSDs, etc.)
* [Installation instructions for macOS](http://luarocks.org/en/Installation_instructions_for_macOS)
* [Installation instructions for Windows](http://luarocks.org/en/Installation_instructions_for_Windows)

## License

LuaRocks is free software and uses the [MIT license](http://luarocks.org/en/License), the same as Lua 5.x.

[1]: http://luarocks.org/en/Types_of_rocks
[2]: http://luarocks.org/en/Dependencies
[3]: http://luarocks.org/en/Rocks_repositories

