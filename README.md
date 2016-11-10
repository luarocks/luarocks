<p align="center"><a href="http://luarocks.org"><img border="0" src="http://luarocks.github.io/luarocks/luarocks.png" alt="LuaRocks" width="500px"></a></p>

A package manager for Lua modules.

[![Build Status](https://travis-ci.org/luarocks/luarocks.svg?branch=master)](https://travis-ci.org/luarocks/luarocks)
[![Build Status](https://ci.appveyor.com/api/projects/status/4x4630tcf64da48i/branch/master?svg=true)](https://ci.appveyor.com/project/hishamhm/luarocks/branch/master)
[![Coverage Status](https://codecov.io/gh/luarocks/luarocks/coverage.svg?branch=master)](https://codecov.io/gh/luarocks/luarocks/branch/master)
[![Join the chat at https://gitter.im/luarocks/luarocks](https://badges.gitter.im/luarocks/luarocks.svg)](https://gitter.im/luarocks/luarocks)

Main website: [luarocks.org](http://www.luarocks.org)

It allows you to install Lua modules as self-contained packages called
[*rocks*][1], which also contain version [dependency][2] information. This
information can be used both during installation, so that when one rock is
requested all rocks it depends on are installed as well, and also optionally
at run time, so that when a module is required, the correct version is loaded.
LuaRocks supports both local and [remote][3] repositories, and multiple local
rocks trees. You can [download][4] and install LuaRocks on [Unix][5] and
[Windows][6].

LuaRocks is free software and uses the same [license][7] as Lua 5.x.

[1]: http://luarocks.org/en/Types_of_rocks
[2]: http://luarocks.org/en/Dependencies
[3]: http://luarocks.org/en/Rocks_repositories
[4]: http://luarocks.org/en/Download
[5]: http://luarocks.org/en/Installation_instructions_for_Unix
[6]: http://luarocks.org/en/Installation_instructions_for_Windows
[7]: http://luarocks.org/en/License
