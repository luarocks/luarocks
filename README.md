<p align="center"><a href="https://luarocks.org"><img border="0" src="https://luarocks.github.io/luarocks/luarocks.png" alt="LuaRocks" width="500px"></a></p>

This is a fork that adds a "nix" command to generate nix packages from
rockspecs.
You can test the fork with `luarocks nix <PACKAGE>`, e.g., `luarocks nix date`.
Due to changes in lua5.2 to the returned value of `os.execute`, please run
`luarocks nix` with lua >= 5.2.

A package manager for Lua modules.

[![Build Status](https://github.com/luarocks/luarocks/actions/workflows/test.yml/badge.svg)](https://github.com/luarocks/luarocks/actions)
[![Coverage Status](https://codecov.io/gh/luarocks/luarocks/branch/main/graph/badge.svg)](https://app.codecov.io/gh/luarocks/luarocks/tree/main)
[![Join the chat at https://gitter.im/luarocks/luarocks](https://badges.gitter.im/luarocks/luarocks.svg)](https://gitter.im/luarocks/luarocks)

Main website: [luarocks.org](https://luarocks.org)

It allows you to install Lua modules as self-contained packages called
*rocks*. LuaRocks supports both local and remote repositories, and
multiple local rocks trees.

## License

LuaRocks is free software and uses the [MIT license](http://luarocks.org/en/License), the same as Lua 5.x.
